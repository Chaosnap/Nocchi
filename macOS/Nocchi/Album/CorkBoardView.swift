import AppKit
import NocchiKit
import SwiftUI

/// 软木板：装在胡桃木框里的一块柔和的软木，照片按月份钉着。
///
/// 每个月一条凸字标签带 + 打字机小纸条；照片用松散的拼贴排布（按 seed 倾斜、错落），
/// 用黄铜图钉、彩色地图针、牛皮纸胶带或木夹固定；三张以上的月份夹一件旧物（票根、邮票、胶片）。
/// 照片钉上去时轻轻落下回弹，鼠标拂过时绕着图钉摆一摆；左下角的「灯光」铜牌可以调台灯的方向、
/// 色温、亮度、暗角、阴影、纸张卷曲与固定方式（`CorkLighting`），阴影和光泽都跟着灯走。
struct CorkBoardView: View {
    let records: [PhotoRecord]
    let libraryIsEmpty: Bool
    @ObservedObject private var lights = CorkLightingStore.shared
    @State private var showsLighting = false

    init(records: [PhotoRecord], libraryIsEmpty: Bool) {
        self.records = records
        self.libraryIsEmpty = libraryIsEmpty
    }

    var body: some View {
        let groups = PhotoLibrary.groupedByMonth(records)
        let lighting = lights.lighting
        WalnutFrame {
            ZStack(alignment: .bottomLeading) {
                CorkSurface(lighting: lighting)
                if libraryIsEmpty {
                    EmptyCorkCard(lighting: lighting)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !groups.isEmpty {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 56) {
                            ForEach(groups) { group in
                                CorkMonth(group: group, lighting: lighting)
                            }
                        }
                        .padding(.horizontal, 44)
                        .padding(.top, 38)
                        .padding(.bottom, 96)
                    }
                }
                if showsLighting {
                    LightingPanel(store: lights) {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { showsLighting = false }
                    }
                    .padding(.leading, 22)
                    .padding(.bottom, 84)
                    .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
                    .zIndex(2)
                }
                LightBadge(active: showsLighting, lighting: lighting) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { showsLighting.toggle() }
                }
                .padding(.leading, 20)
                .padding(.bottom, 18)
                .zIndex(3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

// MARK: - 一个月

private struct CorkMonth: View {
    let group: PhotoLibrary.MonthGroup
    let lighting: CorkLighting

    private static let monthNames = [String(localized: "一月"), String(localized: "二月"), String(localized: "三月"), String(localized: "四月"), String(localized: "五月"), String(localized: "六月"), String(localized: "七月"), String(localized: "八月"), String(localized: "九月"), String(localized: "十月"), String(localized: "十一月"), String(localized: "十二月")]

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .center, spacing: 16) {
                LabelTape(text: title, color: tapeColor, lighting: lighting)
                TypedSlip(text: String(localized: "\(group.records.count) 张"), size: 11.5, tilt: 2.2)
            }
            .padding(.leading, 4)

            CollageLayout {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .photo(let record):
                        PinnedPrint(record: record, lighting: lighting, order: index)
                            .layoutValue(key: CollageSeed.self, value: record.seed)
                    case .ephemera(let kindID, let seed):
                        EphemeraPiece(kindID: kindID, seed: seed, lighting: lighting)
                            .layoutValue(key: CollageSeed.self, value: seed)
                    }
                }
            }
        }
    }

    /// 「2026 · 十一月」
    private var title: String {
        let parts = group.key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else { return group.title }
        return "\(parts[0]) · \(Self.monthNames[month - 1])"
    }

    /// 标签带单月黑、双月酒红。
    private var tapeColor: Color {
        let month = Int(group.key.split(separator: "-").last ?? "") ?? 1
        return month % 2 == 0 ? Color(hex: 0x6B2330) : Color(hex: 0x1E1B19)
    }

    private var monthSeed: UInt64 {
        // FNV-1a：稳定（不用 Swift 每次启动都会变的 hashValue）。
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in group.key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    private var items: [CorkItem] {
        var list = group.records.map { CorkItem.photo($0) }
        if group.records.count >= 3 {
            let seed = monthSeed
            let kinds = ["ephemera.ticket", "ephemera.stamp", "ephemera.filmstrip"]
            let kind = kinds[Int(seed % UInt64(kinds.count))]
            let index = 1 + Int((seed >> 8) % UInt64(list.count - 1))
            list.insert(.ephemera(kind, seed), at: index)
        }
        return list
    }
}

private enum CorkItem: Identifiable {
    case photo(PhotoRecord)
    case ephemera(String, UInt64)

    var id: String {
        switch self {
        case .photo(let record): record.id.uuidString
        case .ephemera(let kind, let seed): "\(kind)#\(seed)"
        }
    }
}

// MARK: - 拼贴排布

private struct CollageSeed: LayoutValueKey {
    static let defaultValue: UInt64 = 0
}

/// 松散的拼贴：按行排，行内居中；每件按 seed 上下错落 ±10、间距 34±8。
private struct CollageLayout: Layout {
    var spacing: CGFloat = 34

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions(by: CGSize(width: 900, height: 600)).width
        return CGSize(width: width, height: arrange(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY),
                anchor: .center,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        var frames: [CGRect] = []
        var row: [Int] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        func closeRow() {
            guard let last = row.last else { return }
            let shift = max(0, (width - frames[last].maxX) / 2)
            for index in row {
                frames[index].origin.x += shift
            }
            y += rowHeight + spacing
            x = 0
            rowHeight = 0
            row.removeAll()
        }

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let seed = subview[CollageSeed.self]
            if !row.isEmpty, x + size.width > width {
                closeRow()
            }
            let dy = CGFloat((seed >> 24) & 0xFF) / 255 * 20 - 10
            frames.append(CGRect(x: x, y: y + 10 + dy, width: size.width, height: size.height))
            row.append(index)
            let gap = spacing + CGFloat((seed >> 32) & 0xFF) / 255 * 16 - 8
            x += size.width + gap
            rowHeight = max(rowHeight, size.height + 20)
        }
        closeRow()
        return (frames, max(0, y - spacing))
    }
}

// MARK: - 钉着的照片

private struct PinnedPrint: View {
    let record: PhotoRecord
    let lighting: CorkLighting
    let order: Int
    @State private var hovering = false
    /// 绕固定点的摆动（度），弹簧回到 0。
    @State private var swing: Double = 0
    @State private var landed = false
    @State private var pinPressed = false
    @State private var lastHover: (x: CGFloat, time: TimeInterval)?
    @State private var lastKick: TimeInterval = 0

    init(record: PhotoRecord, lighting: CorkLighting, order: Int) {
        self.record = record
        self.lighting = lighting
        self.order = order
    }

    var body: some View {
        let width = Self.width(for: record.format)
        let aspect = max(0.1, record.printFile != nil ? record.layout.aspect : record.layout.windowAspect)
        let height = width / aspect
        let fastener = Fastener.pick(seed: record.seed, format: record.format, style: lighting.fastener)
        let swings = fastener.swings
        let shadow = lighting.dropShadow(lifted: hovering)
        let contact = lighting.contactShadow
        ZStack(alignment: .top) {
            AlbumThumbnail(record: record)
                .frame(width: width, height: height)
                .overlay { PaperCurl(lighting: lighting, width: width, height: height) }
                .shadow(color: .black.opacity(contact.opacity), radius: 1.2, x: contact.offset.width, y: contact.offset.height)
                .shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height)
                .scaleEffect(hovering ? 1.035 : 1, anchor: swings ? .top : .center)
            FastenerView(fastener: fastener, width: width, seed: record.seed, lighting: lighting, pressed: pinPressed)
        }
        .frame(width: width, height: height)
        // 静止时的倾斜 + 摆动，都绕着固定点（图钉 / 木夹在上沿正中）转。
        .rotationEffect(.degrees(Self.tilt(record.seed) + (swings ? swing : 0)), anchor: swings ? UnitPoint(x: 0.5, y: 0.02) : .center)
        .offset(y: landed ? 0 : -22)
        .opacity(landed ? 1 : 0)
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if !hovering {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { hovering = true }
                }
                if swings { brush(at: location.x) }
            case .ended:
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { hovering = false }
                lastHover = nil
            }
        }
        .onTapGesture(count: 2) { AlbumActions.open(record) }
        .contextMenu { AlbumContextMenu(record: record) }
        .help("\(record.indexTitle) · \(record.stockName) · \(record.dateText)")
        .onAppear { pinUp() }
    }

    /// 钉上去：从上面轻轻落下、回弹，图钉随后按进去。
    private func pinUp() {
        guard !landed else { return }
        let delay = Double(min(order, 12)) * 0.05 + Double((record.seed >> 3) & 0x0F) / 300
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 13)) {
                landed = true
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { pinPressed = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pinPressed = false }
            kick(by: Double((record.seed >> 13) & 0x07) - 3.5)
        }
    }

    /// 鼠标拂过：按横向速度推一下，像真的挂着的照片那样摆一摆。
    private func brush(at x: CGFloat) {
        let now = Date().timeIntervalSinceReferenceDate
        defer { lastHover = (x, now) }
        guard let last = lastHover, now - last.time < 0.2, now - lastKick > 0.28 else { return }
        let velocity = (x - last.x) / CGFloat(max(now - last.time, 0.008))
        guard abs(velocity) > 60 else { return }
        lastKick = now
        kick(by: Double(min(max(velocity / 90, -5.5), 5.5)))
    }

    private func kick(by degrees: Double) {
        withAnimation(.easeOut(duration: 0.12)) { swing = degrees }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            // 欠阻尼的弹簧：来回摆几下、慢慢停住。
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 34, damping: 2.4)) { swing = 0 }
        }
    }

    /// 按画幅定宽：拍立得 170、迷你 128、宽幅 236、四格条 92、四宫格 150、冲印小照 220。
    static func width(for format: FilmFormat) -> CGFloat {
        switch format {
        case .instantSquare: return 170
        case .instantMini: return 128
        case .instantWide: return 236
        case .boothStrip: return 92
        case .boothGrid: return 150
        case .landscape: return 220
        }
    }

    /// ±5°。
    static func tilt(_ seed: UInt64) -> Double {
        (Double((seed >> 16) & 0xFF) / 255 - 0.5) * 10
    }
}

/// 纸张卷曲：朝着灯的一边亮一点、背着灯的一边暗一点（柔光混合，跟着灯的方向走）。
private struct PaperCurl: View {
    let lighting: CorkLighting
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let toLight = lighting.toLight
        let amount = lighting.curl
        LinearGradient(
            colors: [
                Color.white.opacity(0.32 * amount),
                Color.white.opacity(0.06 * amount),
                Color.black.opacity(0.04 * amount),
                Color.black.opacity(0.26 * amount)
            ],
            startPoint: UnitPoint(x: 0.5 + toLight.dx * 0.5, y: 0.5 + toLight.dy * 0.5),
            endPoint: UnitPoint(x: 0.5 - toLight.dx * 0.5, y: 0.5 - toLight.dy * 0.5)
        )
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

// MARK: - 固定方式

private enum Fastener {
    case brassPin
    case mapPin(String)
    case tape
    case clothespin

    /// 挂在一个点上的会摆（图钉、地图针、木夹），胶带贴住两个角的不摆。
    var swings: Bool {
        if case .tape = self { return false }
        return true
    }

    static func pick(seed: UInt64, format: FilmFormat, style: CorkLighting.Fastener) -> Fastener {
        let pins = ["PinTerracotta", "PinMustard", "PinTeal"]
        switch style {
        case .brass: return .brassPin
        case .mapPin: return .mapPin(pins[Int((seed >> 11) % 3)])
        case .tape: return .tape
        case .clip: return .clothespin
        case .mixed: break
        }
        let roll = (seed >> 5) % 10
        if format.isBooth {
            return roll < 5 ? .clothespin : .tape
        }
        switch roll {
        case 0..<4: return .brassPin
        case 4..<6: return .mapPin(pins[Int((seed >> 11) % 3)])
        case 6..<9: return .tape
        default: return .clothespin
        }
    }
}

private struct FastenerView: View {
    let fastener: Fastener
    let width: CGFloat
    let seed: UInt64
    let lighting: CorkLighting
    let pressed: Bool

    var body: some View {
        switch fastener {
        case .brassPin:
            PropImage(name: "PinBrass", size: CGSize(width: 26, height: 26), fallback: Palette.brass, lighting: lighting, height: 3)
                .scaleEffect(pressed ? 0.86 : 1)
                .offset(y: -11)
        case .mapPin(let name):
            PropImage(name: name, size: CGSize(width: 30, height: 30), fallback: Palette.terracotta, lighting: lighting, height: 7)
                .scaleEffect(pressed ? 0.88 : 1, anchor: .bottom)
                .offset(x: 2, y: -17)
        case .tape:
            let tapeWidth = min(70, width * 0.44)
            HStack(spacing: 0) {
                TapeStrip(width: tapeWidth, seed: seed)
                    .rotationEffect(.degrees(-36))
                    .offset(x: -tapeWidth * 0.26, y: -4)
                Spacer(minLength: 0)
                TapeStrip(width: tapeWidth, seed: seed &+ 1)
                    .rotationEffect(.degrees(38))
                    .offset(x: tapeWidth * 0.26, y: -4)
            }
            .frame(width: width)
        case .clothespin:
            PropImage(name: "Clothespin", size: CGSize(width: 22, height: 44), fallback: Color(hex: 0xD8B07A), lighting: lighting, height: 4)
                .scaleEffect(pressed ? 0.94 : 1, anchor: .top)
                .offset(y: -28)
        }
    }
}

/// Blender 渲染的小道具（图钉、木夹）：渲染图不带地面阴影，这里按轮廓画柔和的接触阴影 + 投影，
/// 方向跟着软木板的灯；`height` 是道具离板面的高度（越高影子离得越远、越虚）。缺图时画一个色块。
private struct PropImage: View {
    let name: String
    let size: CGSize
    let fallback: Color
    let lighting: CorkLighting
    let height: CGFloat

    var body: some View {
        let dir = lighting.shadowDirection
        let far = CGSize(width: dir.dx * (2 + height), height: dir.dy * (2 + height))
        Group {
            if BundledImage.has(name) {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Capsule()
                    .fill(RadialGradient(colors: [fallback.opacity(0.75), fallback], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: size.width * 0.6))
                    .frame(width: min(size.width, size.height) * 0.6, height: min(size.width, size.height) * 0.6)
            }
        }
        .shadow(color: .black.opacity(0.18 + 0.16 * lighting.shadow), radius: 1, x: dir.dx * 0.8, y: dir.dy * 0.8)
        .shadow(color: .black.opacity(0.12 + 0.18 * lighting.shadow), radius: 2.5 + height * 0.5, x: far.width, y: far.height)
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// 一截牛皮纸胶带（程序化绘制，带撕口）。
private struct TapeStrip: View {
    let width: CGFloat
    let seed: UInt64

    var body: some View {
        Group {
            if let image = StickerImageCache.shared.image("tape.kraft", width: width, seed: seed % 4 + 1) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(hex: 0xC9A57A, opacity: 0.82))
                    .frame(height: width / 3.6)
            }
        }
        .frame(width: width)
        .opacity(0.94)
        .allowsHitTesting(false)
    }
}

/// 夹在照片之间的一件旧物。
private struct EphemeraPiece: View {
    let kindID: String
    let seed: UInt64
    let lighting: CorkLighting

    var body: some View {
        let width: CGFloat = kindID == "ephemera.filmstrip" ? 196 : (kindID == "ephemera.ticket" ? 172 : 96)
        let shadow = lighting.dropShadow(lifted: false)
        Group {
            if let image = StickerImageCache.shared.image(kindID, width: width, seed: seed % 7 + 1) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
                    .frame(height: 1)
            }
        }
        .frame(width: width)
        .rotationEffect(.degrees((Double((seed >> 40) & 0xFF) / 255 - 0.5) * 14))
        .shadow(color: .black.opacity(shadow.opacity * 0.8), radius: shadow.radius * 0.5, x: shadow.offset.width * 0.5, y: shadow.offset.height * 0.5)
        .padding(.top, 18)
        .allowsHitTesting(false)
    }
}

// MARK: - 月份标签带

/// 标签机打出来的凸字标签带：深色带子、白色凸字、细竖纹与高光，微微倾斜。
private struct LabelTape: View {
    let text: String
    let color: Color
    let lighting: CorkLighting

    var body: some View {
        let shadow = lighting.dropShadow(lifted: false)
        Text(text)
            .font(RetroFont.label(16))
            .tracking(2.2)
            .foregroundStyle(Color.white.opacity(0.95))
            .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 1)
            .shadow(color: .white.opacity(0.25), radius: 0, x: 0, y: -0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(color)
                    TapeRibs()
                        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear, Color.black.opacity(0.22)], startPoint: .top, endPoint: .bottom))
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 0.8, x: lighting.contactShadow.offset.width, y: lighting.contactShadow.offset.height)
            .shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius * 0.5, x: shadow.offset.width * 0.5, y: shadow.offset.height * 0.5)
            .rotationEffect(.degrees(-2))
            .fixedSize()
    }
}

/// 标签带上的细竖纹。
private struct TapeRibs: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var light = Path()
            var dark = Path()
            while x < size.width {
                light.addRect(CGRect(x: x, y: 0, width: 0.6, height: size.height))
                dark.addRect(CGRect(x: x + 1.1, y: 0, width: 0.6, height: size.height))
                x += 2.2
            }
            context.fill(light, with: .color(Color.white.opacity(0.07)))
            context.fill(dark, with: .color(Color.black.opacity(0.12)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 木框与软木

/// 胡桃木框：四条斜接的木条（上亮下暗），内侧一圈压暗的边。
private struct WalnutFrame<Content: View>: View {
    let content: Content
    private let rail: CGFloat = 22

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlay { CorkInnerShadow() }
            .clipShape(Rectangle())
            .padding(rail)
            .background { WalnutRails(width: rail) }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Palette.walnutDeep.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }
}

private struct WalnutRails: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            Palette.walnut
            if BundledImage.has("WoodTexture") {
                Image("WoodTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.85)
            }
            RailShape(side: .top, width: width).fill(Color.white.opacity(0.14))
            RailShape(side: .left, width: width).fill(Color.white.opacity(0.07))
            RailShape(side: .right, width: width).fill(Color.black.opacity(0.16))
            RailShape(side: .bottom, width: width).fill(Color.black.opacity(0.26))
            MiterSeams(width: width)
                .stroke(Color.black.opacity(0.35), lineWidth: 0.8)
            Rectangle()
                .inset(by: width - 1)
                .stroke(Color.black.opacity(0.55), lineWidth: 2)
            Rectangle()
                .inset(by: 1.5)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

/// 木框的一条边（梯形，四角斜接）。
private struct RailShape: Shape {
    enum Side { case top, left, right, bottom }

    let side: Side
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let o = rect
        let i = rect.insetBy(dx: width, dy: width)
        var path = Path()
        switch side {
        case .top:
            path.addLines([CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.maxX, y: o.minY), CGPoint(x: i.maxX, y: i.minY), CGPoint(x: i.minX, y: i.minY)])
        case .bottom:
            path.addLines([CGPoint(x: o.minX, y: o.maxY), CGPoint(x: o.maxX, y: o.maxY), CGPoint(x: i.maxX, y: i.maxY), CGPoint(x: i.minX, y: i.maxY)])
        case .left:
            path.addLines([CGPoint(x: o.minX, y: o.minY), CGPoint(x: i.minX, y: i.minY), CGPoint(x: i.minX, y: i.maxY), CGPoint(x: o.minX, y: o.maxY)])
        case .right:
            path.addLines([CGPoint(x: o.maxX, y: o.minY), CGPoint(x: i.maxX, y: i.minY), CGPoint(x: i.maxX, y: i.maxY), CGPoint(x: o.maxX, y: o.maxY)])
        }
        path.closeSubpath()
        return path
    }
}

/// 四角的斜接缝。
private struct MiterSeams: Shape {
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let i = rect.insetBy(dx: width, dy: width)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: i.minX, y: i.minY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: i.maxX, y: i.minY))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: i.minX, y: i.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: i.maxX, y: i.maxY))
        return path
    }
}

/// 柔和的软木（`CorkSoft`，Blender 程序化渲染、无缝平铺、细颗粒低反差）+ 台灯光 + 暗角。
private struct CorkSurface: View {
    let lighting: CorkLighting

    var body: some View {
        GeometryReader { geo in
            let toLight = lighting.toLight
            let lightCenter = UnitPoint(x: 0.5 + toLight.dx * 0.48, y: 0.5 + toLight.dy * 0.48)
            let reach = max(geo.size.width, geo.size.height)
            ZStack {
                Color(hex: 0xC6A27B)
                if BundledImage.has("CorkSoft") {
                    Image("CorkSoft")
                        .resizable(resizingMode: .tile)
                } else if BundledImage.has("CorkTexture") {
                    Image("CorkTexture")
                        .resizable(resizingMode: .tile)
                        .opacity(0.45)
                }
                // 台灯光：灯那一边一团暖光
                RadialGradient(
                    colors: [lighting.lightColor.opacity(0.5 * lighting.intensity), lighting.lightColor.opacity(0.12 * lighting.intensity), .clear],
                    center: lightCenter,
                    startRadius: 0,
                    endRadius: reach * 0.95
                )
                .blendMode(.screen)
                // 背光的一边沉下去
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.32 * lighting.vignette)],
                    center: lightCenter,
                    startRadius: reach * 0.35,
                    endRadius: reach * 1.05
                )
                // 整体的明暗
                Color.black.opacity(0.18 * (1 - lighting.intensity))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// 软木嵌在木框里：四边一圈柔和的内阴影。
private struct CorkInnerShadow: View {
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.black.opacity(0.45), lineWidth: 10)
                .blur(radius: 8)
            Rectangle()
                .stroke(Color.black.opacity(0.3), lineWidth: 2)
                .blur(radius: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 空状态

/// 一张用黄铜图钉钉住的打字机卡片。
private struct EmptyCorkCard: View {
    let lighting: CorkLighting

    var body: some View {
        let shadow = lighting.dropShadow(lifted: false)
        VStack(alignment: .leading, spacing: 10) {
            Text("软木板还空着")
                .font(RetroFont.serif(19, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Rectangle()
                .fill(Palette.printRed.opacity(0.5))
                .frame(height: 0.8)
            Text("把鼠标移到刘海，按「屏幕快门」或「自拍」拍第一张。")
                .font(RetroFont.typewriter(13))
                .foregroundStyle(Palette.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 320, alignment: .leading)
        .background(Rectangle().fill(Palette.paper))
        .overlay { PaperCurl(lighting: lighting, width: 320, height: 140) }
        .overlay(alignment: .top) {
            PropImage(name: "PinBrass", size: CGSize(width: 28, height: 28), fallback: Palette.brass, lighting: lighting, height: 3)
                .offset(y: -12)
        }
        .rotationEffect(.degrees(-2))
        .shadow(color: .black.opacity(lighting.contactShadow.opacity), radius: 1.2, x: lighting.contactShadow.offset.width, y: lighting.contactShadow.offset.height)
        .shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height)
    }
}
