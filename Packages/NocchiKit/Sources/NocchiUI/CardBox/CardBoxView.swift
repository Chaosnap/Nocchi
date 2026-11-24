import NocchiKit
import SwiftUI

/// 照片卡片盒（2.5D）：Blender 渲染的山毛榉木索引卡盒在左，抽出来的照片卡片在右边扇形摊开。
///
/// 图层（下 → 上）：背景 → `CardBoxBase`（盒子、卡片、分隔卡、笔）→ 正在升起的卡片 →
/// `CardBoxFront`（前挡板与右侧板，挡住卡片的下半截）→ 分隔卡标签热区 → 摊开的卡片。
/// 点分隔卡标签：这一组照片一张张从盒口升起、飞到右边。单击卡片置顶，双击打开，左右拖动翻看。
public struct CardBoxView: View {
    @ObservedObject var model: CardBoxModel
    private let menu: ((PhotoRecord) -> AnyView)?
    @StateObject private var flights = CardFlights()
    @State private var hoveredTab: String?
    @State private var hoveredCard: UUID?

    public init(model: CardBoxModel) {
        self.model = model
        self.menu = nil
    }

    /// 带右键菜单的卡片盒。
    public init<Menu: View>(model: CardBoxModel, @ViewBuilder contextMenu: @escaping (PhotoRecord) -> Menu) {
        self.model = model
        self.menu = { AnyView(contextMenu($0)) }
    }

    public var body: some View {
        GeometryReader { geo in
            let stage = CardBoxStage(size: geo.size)
            let fan = FanLayout(stage: stage, order: flights.order, leaving: flights.leaving)
            ZStack(alignment: .topLeading) {
                CardBoxBackdrop(stage: stage)
                    .zIndex(-1)
                BoxArt(name: "CardBoxBase", stage: stage, fallback: true)
                    .zIndex(0)
                ForEach(flights.order, id: \.self) { id in
                    if let record = model.record(id: id) {
                        card(record, fan: fan)
                    }
                }
                BoxArt(name: "CardBoxFront", stage: stage, fallback: false)
                    .allowsHitTesting(false)
                    .zIndex(1)
                tabLayer(stage)
                    .zIndex(2)
                if let letter = hoveredTab, let tab = CardBoxHotspots.tab(for: letter) {
                    TabChip(letter: letter, count: model.count(for: letter))
                        .position(stage.point(tab.center).applying(CGAffineTransform(translationX: 0, y: -stage.tabSize.height * 1.35)))
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(3)
                }
                spreadChrome(stage)
                    .zIndex(200)
                if model.records.isEmpty {
                    EmptyBoxCard()
                        .position(x: stage.spread.midX, y: stage.spread.midY)
                        .zIndex(201)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(pageGesture(stage))
        }
        .onAppear { flights.sync(with: model.pulled) }
        .onChange(of: model.pulled) { _, pulled in
            flights.sync(with: pulled)
        }
    }

    // MARK: - 卡片

    private func card(_ record: PhotoRecord, fan: FanLayout) -> some View {
        let id = record.id
        let placement = fan.placement(for: id, phase: flights.phase(of: id), seed: record.seed)
        let lifted = hoveredCard == id && flights.phase(of: id) == .spread
        return PhotoIndexCard(record: record, image: model.image(for: record), size: fan.stage.cardSize, lifted: lifted)
            .scaleEffect(placement.scale * (lifted ? 1.03 : 1))
            .rotationEffect(.degrees(placement.rotation))
            .offset(y: lifted ? -6 : 0)
            .opacity(placement.opacity)
            // 交互要放在 .position 之前：.position 之后的视图铺满整个舞台。
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
            .contextMenu {
                if let menu {
                    menu(record)
                }
                Button("放回盒子") { model.putBack(id) }
            }
            .help(record.indexTitle)
            .position(placement.center)
            .zIndex(placement.z)
    }

    // MARK: - 分隔卡标签

    private func tabLayer(_ stage: CardBoxStage) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(CardBoxHotspots.tabs, id: \.letter) { tab in
                TabHotspot(
                    count: model.count(for: tab.letter),
                    active: model.activeLetter == tab.letter,
                    hovered: hoveredTab == tab.letter,
                    size: stage.tabSize
                )
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.14)) {
                        if inside {
                            hoveredTab = tab.letter
                        } else if hoveredTab == tab.letter {
                            hoveredTab = nil
                        }
                    }
                }
                .onTapGesture { model.pull(letter: tab.letter) }
                .help(model.count(for: tab.letter) > 0 ? "抽出 \(tab.letter) 组" : "\(tab.letter) 组还是空的")
                .position(stage.point(tab.center))
            }
        }
    }

    // MARK: - 摊开区的按钮与说明

    private func spreadChrome(_ stage: CardBoxStage) -> some View {
        ZStack(alignment: .topLeading) {
            if !model.pulled.isEmpty {
                PutBackButton { model.putBackAll() }
                    .position(x: stage.spread.maxX - 62, y: stage.spread.minY + 4)
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
    }

    /// 在摊开区左右拖动：往左翻到下一张，往右翻回上一张。
    private func pageGesture(_ stage: CardBoxStage) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard value.startLocation.x > stage.spread.minX, abs(value.translation.width) > abs(value.translation.height) else { return }
                let steps = max(1, min(4, Int(abs(value.translation.width) / 90)))
                for _ in 0..<steps {
                    if value.translation.width < 0 {
                        model.cycleTop()
                    } else {
                        model.cycleBottom()
                    }
                }
            }
    }
}

// MARK: - 舞台几何

/// 卡片盒在视图里的摆放：渲染图放在左边（盒子约占宽度 44%），右边是摊开区。
struct CardBoxStage {
    let size: CGSize
    /// 1600×1200 渲染图在视图里的位置。
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

    /// 分隔卡标签在视图里的大小（渲染图里约 60×44 像素）。
    var tabSize: CGSize {
        let k = imageFrame.width / 1600
        return CGSize(width: max(22, 62 * k), height: max(16, 44 * k))
    }

    /// 盒子里一张卡片相对于摊开时的大小（和渲染图里的分隔卡差不多大）。
    var inBoxScale: CGFloat {
        min(0.6, imageFrame.width * 0.095 / cardSize.width)
    }
}

/// 每张卡片在当前阶段的位置、大小、角度、层次。
struct CardPlacement {
    var center: CGPoint
    var scale: CGFloat
    var rotation: Double
    var z: Double
    var opacity: Double
}

/// 右边的扇形：最多摊开 9 张，最上面的一张在最右、完整可见。
struct FanLayout {
    let stage: CardBoxStage
    /// 摊开的卡片（下 → 上），只取最上面的 9 张；更下面的藏在扇形后面。
    let visible: [UUID]

    init(stage: CardBoxStage, order: [UUID], leaving: Set<UUID>) {
        self.stage = stage
        visible = Array(order.filter { !leaving.contains($0) }.suffix(CardBoxModel.spreadLimit))
    }

    func placement(for id: UUID, phase: CardFlights.Phase, seed: UInt64) -> CardPlacement {
        let slot = stage.point(CardBoxHotspots.slot)
        let small = stage.inBoxScale
        let cardHeight = stage.cardSize.height * small
        switch phase {
        case .inBox:
            return CardPlacement(center: CGPoint(x: slot.x, y: slot.y + cardHeight * 0.62), scale: small, rotation: -2, z: 0.5, opacity: 1)
        case .rising:
            return CardPlacement(center: CGPoint(x: slot.x, y: slot.y - cardHeight * 0.58), scale: small * 1.08, rotation: -2, z: 0.5, opacity: 1)
        case .hovering:
            return CardPlacement(center: CGPoint(x: slot.x, y: slot.y - cardHeight * 0.58), scale: small * 1.08, rotation: -2, z: 150, opacity: 1)
        case .spread:
            if let index = visible.firstIndex(of: id) {
                return fanPlacement(index: index, count: visible.count, seed: seed)
            }
            // 叠在最下面、看不见的卡片：藏在扇形最左边那张后面。
            var placement = fanPlacement(index: 0, count: max(visible.count, 1), seed: seed)
            placement.z = 9
            placement.opacity = 0
            placement.scale = 0.96
            return placement
        }
    }

    private func fanPlacement(index: Int, count: Int, seed: UInt64) -> CardPlacement {
        let area = stage.spread
        let cardWidth = stage.cardSize.width
        let step: CGFloat = count > 1 ? min(cardWidth * 0.36, (area.width - cardWidth) / CGFloat(count - 1)) : 0
        let total = cardWidth + step * CGFloat(max(count - 1, 0))
        let x = area.midX - total / 2 + cardWidth / 2 + CGFloat(index) * step
        let t: CGFloat = count > 1 ? CGFloat(index) / CGFloat(count - 1) - 0.5 : 0
        let jitterY = CGFloat(Self.unit(seed, shift: 8)) * 16 - 8
        let jitterAngle = Self.unit(seed, shift: 24) * 4 - 2
        let y = area.midY - 6 + t * t * 70 + jitterY
        return CardPlacement(
            center: CGPoint(x: x, y: y),
            scale: 1,
            rotation: Double(t) * 8 + jitterAngle,
            z: 10 + Double(index),
            opacity: 1
        )
    }

    /// seed 里取 8 位，映射到 0…1。
    static func unit(_ seed: UInt64, shift: UInt64) -> Double {
        Double((seed >> shift) & 0xFF) / 255
    }
}
