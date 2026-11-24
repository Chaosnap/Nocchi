import AppKit
import NocchiKit
import SwiftUI

/// 软木板：装在胡桃木框里的一块软木，照片按月份钉着。
///
/// 每个月一条凸字标签带 + 打字机小纸条；照片用松散的拼贴排布（按 seed 倾斜、错落），
/// 用黄铜图钉、彩色地图针、牛皮纸胶带或木夹固定；三张以上的月份夹一件旧物（票根、邮票、胶片）。
struct CorkBoardView: View {
    let records: [PhotoRecord]
    let libraryIsEmpty: Bool

    var body: some View {
        let groups = PhotoLibrary.groupedByMonth(records)
        WalnutFrame {
            ZStack {
                CorkSurface()
                if libraryIsEmpty {
                    EmptyCorkCard()
                } else if !groups.isEmpty {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 56) {
                            ForEach(groups) { group in
                                CorkMonth(group: group)
                            }
                        }
                        .padding(.horizontal, 44)
                        .padding(.top, 38)
                        .padding(.bottom, 60)
                    }
                }
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

    private static let monthNames = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .center, spacing: 16) {
                LabelTape(text: title, color: tapeColor)
                TypedSlip(text: "\(group.records.count) 张", size: 11.5, tilt: 2.2)
            }
            .padding(.leading, 4)

            CollageLayout {
                ForEach(items) { item in
                    switch item {
                    case .photo(let record):
                        PinnedPrint(record: record)
                            .layoutValue(key: CollageSeed.self, value: record.seed)
                    case .ephemera(let kindID, let seed):
                        EphemeraPiece(kindID: kindID, seed: seed)
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
    @State private var hovering = false

    init(record: PhotoRecord) {
        self.record = record
    }

    var body: some View {
        let width = Self.width(for: record.format)
        let aspect = max(0.1, record.printFile != nil ? record.layout.aspect : record.layout.windowAspect)
        let height = width / aspect
        ZStack(alignment: .top) {
            AlbumThumbnail(record: record)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.3), radius: 1.2, x: 0.5, y: 1)
                .shadow(color: .black.opacity(hovering ? 0.34 : 0.24), radius: hovering ? 16 : 10, x: 4, y: hovering ? 12 : 7)
                .scaleEffect(hovering ? 1.04 : 1)
            FastenerView(fastener: Fastener.pick(seed: record.seed, format: record.format), width: width, seed: record.seed)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(Self.tilt(record.seed)))
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { hovering = inside }
        }
        .onTapGesture(count: 2) { AlbumActions.open(record) }
        .contextMenu { AlbumContextMenu(record: record) }
        .help("\(record.indexTitle) · \(record.stockName) · \(record.dateText)")
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
        default: return 170
        }
    }

    /// ±5°。
    static func tilt(_ seed: UInt64) -> Double {
        (Double((seed >> 16) & 0xFF) / 255 - 0.5) * 10
    }
}

// MARK: - 固定方式

private enum Fastener {
    case brassPin
    case mapPin(String)
    case tape
    case clothespin

    static func pick(seed: UInt64, format: FilmFormat) -> Fastener {
        let roll = (seed >> 5) % 10
        if format.isBooth {
            return roll < 5 ? .clothespin : .tape
        }
        let pins = ["PinTerracotta", "PinMustard", "PinTeal"]
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

    var body: some View {
        switch fastener {
        case .brassPin:
            PropImage(name: "PinBrass", size: CGSize(width: 26, height: 26), fallback: Palette.brass)
                .offset(y: -11)
        case .mapPin(let name):
            PropImage(name: name, size: CGSize(width: 30, height: 30), fallback: Palette.terracotta)
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
            PropImage(name: "Clothespin", size: CGSize(width: 22, height: 44), fallback: Color(hex: 0xD8B07A))
                .offset(y: -28)
        }
    }
}

/// Blender 渲染的小道具（图钉、木夹），缺图时画一个色块。
private struct PropImage: View {
    let name: String
    let size: CGSize
    let fallback: Color

    var body: some View {
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
                    .shadow(color: .black.opacity(0.35), radius: 1.5, x: 1.5, y: 2)
            }
        }
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

    var body: some View {
        let width: CGFloat = kindID == "ephemera.filmstrip" ? 196 : (kindID == "ephemera.ticket" ? 172 : 96)
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
        .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 3)
        .padding(.top, 18)
        .allowsHitTesting(false)
    }
}

// MARK: - 月份标签带

/// 标签机打出来的凸字标签带：深色带子、白色凸字、细竖纹与高光，微微倾斜。
private struct LabelTape: View {
    let text: String
    let color: Color

    var body: some View {
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
            .shadow(color: .black.opacity(0.4), radius: 0.8, y: 1)
            .shadow(color: .black.opacity(0.22), radius: 6, x: 2, y: 4)
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

/// 软木：`CorkTexture` 平铺 + 左上暖光 + 右下压暗。
private struct CorkSurface: View {
    var body: some View {
        ZStack {
            Color(hex: 0xB88A5C)
            if BundledImage.has("CorkTexture") {
                Image("CorkTexture")
                    .resizable(resizingMode: .tile)
            }
            LinearGradient(colors: [Color(hex: 0xFFE7BF, opacity: 0.22), .clear], startPoint: .topLeading, endPoint: .center)
            LinearGradient(colors: [.clear, Color.black.opacity(0.24)], startPoint: .center, endPoint: .bottomTrailing)
        }
    }
}

/// 软木嵌在木框里：四边一圈柔和的内阴影。
private struct CorkInnerShadow: View {
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.black.opacity(0.5), lineWidth: 10)
                .blur(radius: 7)
            Rectangle()
                .stroke(Color.black.opacity(0.35), lineWidth: 2)
                .blur(radius: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 空状态

/// 一张用黄铜图钉钉住的打字机卡片。
private struct EmptyCorkCard: View {
    var body: some View {
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
        .overlay(alignment: .top) {
            PropImage(name: "PinBrass", size: CGSize(width: 28, height: 28), fallback: Palette.brass)
                .offset(y: -12)
        }
        .rotationEffect(.degrees(-2))
        .shadow(color: .black.opacity(0.28), radius: 1.2, x: 0.5, y: 1)
        .shadow(color: .black.opacity(0.22), radius: 14, x: 4, y: 10)
    }
}
