import NocchiKit
import SwiftUI

/// 照片卡片盒（2.5D）：Blender 渲染的山毛榉木索引卡盒在左，抽出来的照片卡片在右边松松地叠成一摞。
///
/// 图层（下 → 上）：背景 → `CardBoxBase`（盒子、卡片、分隔卡、笔）→ 正在抽出的卡片（被格口线遮住下半截）→
/// `CardBoxFront`（前挡板与右侧板）→ 标签热区 → 落在右边的卡片。
/// 点分隔卡标签：这一组照片从自己那一格里一张张斜着抽出来、转正、落到右边。单击置顶，双击打开，
/// 拖动摆放（放到另一张上面会叠成一摞，位置会记住），在空白处左右拖动翻看。
///
/// 照片按 `CardBoxModel.indexMode` 归档（首字母 / 年 / 月 / 日）：渲染图里的分隔卡标签是空白的，
/// 标签上的字由 `TabLabels` 按标签面的四个角斜切着印上去，换归档方式时跟着变。
public struct CardBoxView: View {
    @ObservedObject var model: CardBoxModel
    private let menu: ((PhotoRecord) -> AnyView)?
    @StateObject private var flights = CardFlights()
    @State private var hoveredTab: String?
    @State private var hoveredCard: UUID?
    @State private var drag: CardDrag?

    public init(model: CardBoxModel) {
        self.model = model
        self.menu = nil
    }

    /// 带右键菜单的卡片盒。
    public init<Menu: View>(model: CardBoxModel, @ViewBuilder contextMenu: @escaping (PhotoRecord) -> Menu) {
        self.model = model
        self.menu = { AnyView(contextMenu($0)) }
    }

    static let space = "cardStage"

    public var body: some View {
        GeometryReader { geo in
            let stage = CardBoxStage(size: geo.size)
            let pile = PileLayout(stage: stage, order: flights.order, leaving: flights.leaving, spots: model.spots)
            ZStack(alignment: .topLeading) {
                CardBoxBackdrop(stage: stage)
                    .zIndex(-1)
                BoxArt(name: "CardBoxBase", stage: stage, fallback: true)
                    .zIndex(0)
                TabLabels(
                    tabs: model.index.tabs,
                    mode: model.index.mode,
                    stage: stage,
                    hoveredKey: hoveredTab,
                    activeKey: model.activeKey
                )
                .zIndex(0.1)
                pagingSurface(stage)
                    .zIndex(0.2)
                ForEach(flights.order, id: \.self) { id in
                    if let record = model.record(id: id) {
                        card(record, pile: pile)
                    }
                }
                BoxArt(name: "CardBoxFront", stage: stage, fallback: false)
                    .allowsHitTesting(false)
                    .zIndex(1)
                tabLayer(stage)
                    .zIndex(2)
                if let key = hoveredTab, let tab = model.index.tab(forKey: key) {
                    let face = TabFace(slot: tab.slot, stage: stage)
                    TabChip(title: tab.title, count: tab.count)
                        .position(face.chipAnchor)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                        .zIndex(3)
                }
                spreadChrome(stage)
                    .zIndex(400)
                if model.records.isEmpty {
                    EmptyBoxCard()
                        .position(x: stage.spread.midX, y: stage.spread.midY)
                        .zIndex(401)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: Self.space)
            .clipped()
        }
        .onAppear { flights.sync(with: model.pulled) }
        .onChange(of: model.pulled) { _, pulled in
            flights.sync(with: pulled)
        }
    }

    // MARK: - 卡片

    private func card(_ record: PhotoRecord, pile: PileLayout) -> some View {
        let id = record.id
        let phase = flights.phase(of: id)
        let slot = SlotGeometry(slot: model.index.slot(for: record), stage: pile.stage)
        let placement = pile.placement(for: id, phase: phase, slot: slot, seed: record.seed)
        let dragging = drag?.id == id
        let lifted = (hoveredCard == id || dragging) && phase == .spread
        let offset = dragging ? (drag?.translation ?? .zero) : .zero
        return PhotoIndexCard(record: record, tabLabel: model.index.label(for: record), image: model.image(for: record), size: pile.stage.cardSize, lifted: lifted)
            .modifier(CardSkew(flatness: placement.flatness, shear: slot.shear))
            .scaleEffect(lifted ? 1.03 : 1)
            .rotationEffect(.degrees(placement.rotation))
            .offset(y: lifted && !dragging ? -5 : 0)
            .opacity(placement.opacity)
            // 交互放在 .position 之前：.position 之后的视图铺满整个舞台。
            .onAppear { model.loadImage(for: record) }
            .onHover { inside in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if inside {
                        hoveredCard = id
                    } else if hoveredCard == id {
                        hoveredCard = nil
                    }
                }
            }
            .onTapGesture(count: 2) { model.onOpen?(record) }
            .onTapGesture { model.bringToFront(id) }
            .gesture(moveGesture(id: id, placement: placement, pile: pile, seed: record.seed))
            .contextMenu {
                if let menu {
                    menu(record)
                }
                if model.spots[id] != nil {
                    Button("放回那一叠") { model.setSpot(nil, for: id) }
                }
                Button("放回盒子") { model.putBack(id) }
            }
            .help(record.indexTitle)
            .allowsHitTesting(phase == .spread)
            .position(x: placement.center.x + offset.width, y: placement.center.y + offset.height)
            .mask { SlotMask(slot: slot, masked: phase.masked) }
            .zIndex(dragging ? 350 : placement.z)
    }

    /// 拖动摆放：放到另一张卡片附近就叠上去；记住位置。
    private func moveGesture(id: UUID, placement: CardPlacement, pile: PileLayout, seed: UInt64) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag?.id != id {
                    // 先把当前位置记下来，再置顶，免得置顶后默认位置变了、卡片跳一下。
                    if model.spots[id] == nil {
                        model.setSpot(pile.spot(at: placement.center, rotation: placement.rotation), for: id)
                    }
                    model.bringToFront(id)
                    drag = CardDrag(id: id, translation: .zero)
                }
                drag?.translation = value.translation
            }
            .onEnded { value in
                let start = pile.center(of: model.spots[id], fallback: placement.center)
                let dropped = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                let rotation = model.spots[id]?.rotation ?? placement.rotation
                var spot = pile.spot(at: dropped, rotation: rotation)
                if let neighbour = pile.nearestCard(to: dropped, excluding: id, spots: model.spots, within: 72) {
                    // 叠上去：对齐那一张，错开一点、换一点角度。
                    let jitter = (Double((seed >> 9) & 0xFF) / 255 - 0.5) * 6
                    spot = pile.spot(at: CGPoint(x: neighbour.center.x + 12, y: neighbour.center.y + 14), rotation: neighbour.rotation + jitter)
                }
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    model.setSpot(spot, for: id)
                    drag = nil
                }
                SoundPlayer.shared.play(.cardSlide)
            }
    }

    /// 摊开区的空白处：左右拖动翻看（往左翻到下一张，往右翻回上一张）。
    private func pagingSurface(_ stage: CardBoxStage) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: stage.spread.width, height: stage.spread.height)
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let steps = max(1, min(4, Int(abs(value.translation.width) / 90)))
                        for _ in 0..<steps {
                            if value.translation.width < 0 {
                                model.cycleTop()
                            } else {
                                model.cycleBottom()
                            }
                        }
                    }
            )
            .position(x: stage.spread.midX, y: stage.spread.midY)
    }

    // MARK: - 分隔卡标签

    /// 标签热区：从后往前排，前面的标签压在后面的上面（重叠的地方点到的是看得见的那张）。
    private func tabLayer(_ stage: CardBoxStage) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.index.tabs.reversed())) { tab in
                let face = TabFace(slot: tab.slot, stage: stage)
                TabHotspot(face: face)
                    .onHover { inside in
                        withAnimation(.easeOut(duration: 0.14)) {
                            if inside {
                                hoveredTab = tab.key
                            } else if hoveredTab == tab.key {
                                hoveredTab = nil
                            }
                        }
                    }
                    .onTapGesture { model.pull(key: tab.key) }
                    .help(tabHelp(tab))
                    .position(x: face.hitBox.midX, y: face.hitBox.midY)
            }
        }
    }

    private func tabHelp(_ tab: CardTab) -> String {
        let name = model.groupName(tab)
        return tab.count > 0
            ? String(localized: "抽出 \(name)", bundle: .main)
            : String(localized: "\(name)还是空的", bundle: .main)
    }

    // MARK: - 摊开区的按钮与说明

    private func spreadChrome(_ stage: CardBoxStage) -> some View {
        ZStack(alignment: .topLeading) {
            if !model.pulled.isEmpty {
                HStack(spacing: 8) {
                    if !model.spots.isEmpty {
                        PutBackButton(title: "重新叠好", symbol: "square.stack") { model.clearSpots() }
                            .transition(.opacity)
                    }
                    PutBackButton(title: "全部放回", symbol: "arrow.uturn.backward") { model.putBackAll() }
                }
                .position(x: stage.spread.maxX - (model.spots.isEmpty ? 62 : 120), y: stage.spread.minY + 4)
                .transition(.opacity)
            }
            if let caption = model.spreadCaption, !model.pulled.isEmpty {
                SpreadCaption(text: caption, more: model.pulled.count > CardBoxModel.spreadLimit)
                    .position(x: stage.spread.midX, y: stage.spread.maxY - 6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.pulled.isEmpty)
        .animation(.easeOut(duration: 0.2), value: model.spots.isEmpty)
    }
}

/// 正在拖动的那张卡片。
struct CardDrag: Equatable {
    let id: UUID
    var translation: CGSize
}

// MARK: - 舞台几何

/// 卡片盒在视图里的摆放：渲染图放在左边（盒子约占宽度 44%），右边是摊开区。
struct CardBoxStage {
    let size: CGSize
    /// 渲染图在视图里的位置。
    let imageFrame: CGRect
    /// 右边的摊开区。
    let spread: CGRect
    /// 摊开时一张卡片的大小。
    let cardSize: CGSize

    init(size: CGSize) {
        self.size = size
        let aspect = CardBoxHotspots.canvasAspect
        let box = CardBoxHotspots.boxBounds
        let width = max(1, min(size.width * 0.44 / box.width, size.height * 0.9 / box.height * aspect))
        let height = width / aspect
        let x = size.width * 0.03 - box.minX * width
        let y = size.height * 0.5 - box.midY * height
        imageFrame = CGRect(x: x, y: y, width: width, height: height)
        let boxRight = x + box.maxX * width
        let spreadMinX = boxRight - width * 0.03
        spread = CGRect(
            x: spreadMinX,
            y: size.height * 0.1,
            width: max(160, size.width * 0.975 - spreadMinX),
            height: size.height * 0.8
        )
        let cardWidth = min(230, max(150, min(spread.width * 0.42, spread.height * 0.62)))
        cardSize = CGSize(width: cardWidth, height: cardWidth * 1.3)
    }

    /// 渲染图上的归一化坐标 → 视图坐标。
    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: imageFrame.minX + p.x * imageFrame.width, y: imageFrame.minY + p.y * imageFrame.height)
    }

    /// 画布像素 → 视图点。
    var pixelScale: CGFloat {
        imageFrame.width / CardBoxHotspots.canvas.width
    }

    /// 分隔卡标签在视图里的大小（渲染图里约 62×44 像素 @1600）。
    var tabSize: CGSize {
        let k = imageFrame.width / 1600
        return CGSize(width: max(22, 62 * k), height: max(16, 44 * k))
    }
}

/// 一个字母那一格：分隔卡上沿（格口线）、卡片立在格子里时的斜切变换。
struct SlotGeometry {
    /// 格口线上、这一格正中的一点。
    let center: CGPoint
    /// 格口线方向（单位向量，往右上）。
    let direction: CGVector
    /// 卡片立在格子里时的样子（围绕卡片中心的仿射变换：宽边顺着分隔卡上沿、竖边朝下）。
    let shear: CGAffineTransform
    /// 立在格子里时卡片的竖向高度（视图点）。
    let heightInBox: CGFloat

    init(slot: Int, stage: CardBoxStage) {
        let dir = CardBoxHotspots.dividerDirection
        let length = CardBoxHotspots.dividerLength * stage.pixelScale
        // 标签沿分隔卡上沿错开排在 5 个位置：标签中心在分隔卡宽度的这些位置（make_cardbox.py：
        // 内宽 13.35、标签宽 2.8、两头各留 0.5）。从标签下沿的中点退回分隔卡上沿的中点。
        let fractions: [CGFloat] = [0.142, 0.321, 0.5, 0.679, 0.858]
        let fraction = fractions[max(slot, 0) % fractions.count]
        let top = TabFace(slot: slot, stage: stage).bottomCenter
        center = CGPoint(x: top.x + dir.dx * (0.5 - fraction) * length, y: top.y + dir.dy * (0.5 - fraction) * length)
        direction = dir
        let cardWidth = stage.cardSize.width
        let cardHeight = stage.cardSize.height
        let edge = length * 0.82
        heightInBox = edge * 0.62 * cardHeight / cardWidth
        shear = CGAffineTransform(a: dir.dx * edge / cardWidth, b: dir.dy * edge / cardWidth, c: 0, d: heightInBox / cardHeight, tx: 0, ty: 0)
    }
}

/// 卡片立在格子里（斜切）↔ 转正（单位变换）之间的过渡。
struct CardSkew: GeometryEffect {
    /// 0 = 和分隔卡同一个斜面，1 = 正对着你。
    var flatness: CGFloat
    let shear: CGAffineTransform

    var animatableData: CGFloat {
        get { flatness }
        set { flatness = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = min(max(flatness, 0), 1)
        let m = CGAffineTransform(
            a: shear.a + (1 - shear.a) * t,
            b: shear.b * (1 - t),
            c: shear.c * (1 - t),
            d: shear.d + (1 - shear.d) * t,
            tx: 0,
            ty: 0
        )
        let centered = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(m)
            .concatenating(CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
        return ProjectionTransform(centered)
    }
}

/// 格口线以下（前面的卡片和分隔卡挡住的地方）看不见：整块舞台减去格口线下方的平行四边形。
struct SlotMask: View {
    let slot: SlotGeometry
    let masked: Bool

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                if masked {
                    let reach: CGFloat = 1200
                    let a = CGPoint(x: slot.center.x - slot.direction.dx * reach, y: slot.center.y - slot.direction.dy * reach)
                    let b = CGPoint(x: slot.center.x + slot.direction.dx * reach, y: slot.center.y + slot.direction.dy * reach)
                    path.move(to: a)
                    path.addLine(to: b)
                    path.addLine(to: CGPoint(x: b.x, y: b.y + 3000))
                    path.addLine(to: CGPoint(x: a.x, y: a.y + 3000))
                    path.closeSubpath()
                }
            }
            .fill(style: FillStyle(eoFill: true))
        }
    }
}

/// 每张卡片在当前阶段的位置、角度、层次。
struct CardPlacement {
    var center: CGPoint
    var rotation: Double
    var z: Double
    var opacity: Double
    /// 0 = 斜立在格子里，1 = 正对着你。
    var flatness: CGFloat
}

/// 右边那一叠：最上面的一张在中间、完整可见，其余错落着从四周露出来（参考照相馆桌上随手叠的样张）。
struct PileLayout {
    let stage: CardBoxStage
    /// 摊开的卡片（下 → 上），只取最上面的 9 张；更下面的藏在这一叠后面。
    let visible: [UUID]
    let spots: [UUID: CardSpot]

    /// 从最上面往下数第 k 张的默认位置（以卡片尺寸为单位的偏移）与角度。
    private static let pattern: [(dx: CGFloat, dy: CGFloat, angle: Double)] = [
        (0.0, 0.05, -1.5), (-0.31, -0.07, -5.5), (0.31, -0.13, 4.5), (-0.07, -0.25, -2),
        (-0.45, 0.07, -7.5), (0.43, 0.03, 6.5), (0.13, -0.31, 2.5), (-0.25, -0.33, -4), (0.31, -0.36, 5)
    ]

    init(stage: CardBoxStage, order: [UUID], leaving: Set<UUID>, spots: [UUID: CardSpot]) {
        self.stage = stage
        visible = Array(order.filter { !leaving.contains($0) }.suffix(CardBoxModel.spreadLimit))
        self.spots = spots
    }

    var pileCenter: CGPoint {
        CGPoint(x: stage.spread.midX, y: stage.spread.midY + stage.cardSize.height * 0.06)
    }

    func placement(for id: UUID, phase: CardFlights.Phase, slot: SlotGeometry, seed: UInt64) -> CardPlacement {
        switch phase {
        case .inBox:
            return CardPlacement(center: CGPoint(x: slot.center.x, y: slot.center.y + slot.heightInBox / 2 + 6), rotation: 0, z: 0.5, opacity: 1, flatness: 0)
        case .rising:
            return CardPlacement(center: CGPoint(x: slot.center.x, y: slot.center.y - slot.heightInBox / 2), rotation: 0, z: 0.5, opacity: 1, flatness: 0)
        case .lifted:
            return CardPlacement(
                center: CGPoint(x: slot.center.x + stage.cardSize.width * 0.28, y: slot.center.y - slot.heightInBox * 0.5 - stage.cardSize.height * 0.42),
                rotation: 2,
                z: 300,
                opacity: 1,
                flatness: 0.6
            )
        case .spread:
            return spreadPlacement(for: id, seed: seed)
        }
    }

    private func spreadPlacement(for id: UUID, seed: UInt64) -> CardPlacement {
        let index = visible.firstIndex(of: id)
        let z = 10 + Double(index ?? 0)
        if let spot = spots[id] {
            return CardPlacement(center: center(of: spot, fallback: pileCenter), rotation: spot.rotation, z: z, opacity: index == nil ? 0 : 1, flatness: 1)
        }
        guard let index else {
            // 叠在最下面、看不见的卡片：藏在这一叠后面。
            return CardPlacement(center: pileCenter, rotation: 0, z: 9, opacity: 0, flatness: 1)
        }
        let depth = visible.count - 1 - index
        let base = Self.pattern[min(depth, Self.pattern.count - 1)]
        let jx = CGFloat((seed >> 8) & 0xFF) / 255 - 0.5
        let jy = CGFloat((seed >> 16) & 0xFF) / 255 - 0.5
        let ja = Double((seed >> 24) & 0xFF) / 255 - 0.5
        let size = stage.cardSize
        let x = pileCenter.x + (base.dx + jx * 0.06) * size.width
        let y = pileCenter.y + (base.dy + jy * 0.05) * size.height
        return CardPlacement(center: CGPoint(x: x, y: y), rotation: base.angle + ja * 2.4, z: z, opacity: 1, flatness: 1)
    }

    /// 摊开区里的位置 → 记下来的相对位置。
    func spot(at point: CGPoint, rotation: Double) -> CardSpot {
        let area = stage.spread
        let x = min(max((point.x - area.minX) / max(area.width, 1), -0.05), 1.05)
        let y = min(max((point.y - area.minY) / max(area.height, 1), 0.0), 1.0)
        return CardSpot(x: Double(x), y: Double(y), rotation: rotation)
    }

    func center(of spot: CardSpot?, fallback: CGPoint) -> CGPoint {
        guard let spot else { return fallback }
        let area = stage.spread
        return CGPoint(x: area.minX + CGFloat(spot.x) * area.width, y: area.minY + CGFloat(spot.y) * area.height)
    }

    /// 离这一点最近的另一张看得见的卡片（用来叠成一摞）。
    func nearestCard(to point: CGPoint, excluding id: UUID, spots: [UUID: CardSpot], within radius: CGFloat) -> (center: CGPoint, rotation: Double)? {
        var best: (center: CGPoint, rotation: Double)?
        var bestDistance = radius
        for other in visible where other != id {
            let placement: CardPlacement
            if let spot = spots[other] {
                placement = CardPlacement(center: center(of: spot, fallback: pileCenter), rotation: spot.rotation, z: 0, opacity: 1, flatness: 1)
            } else {
                placement = spreadPlacement(for: other, seed: 0)
            }
            let distance = hypot(placement.center.x - point.x, placement.center.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = (placement.center, placement.rotation)
            }
        }
        return best
    }
}
