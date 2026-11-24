import AppKit
import NocchiKit
import SwiftUI

/// 胶卷：胡桃木桌上的一块光台，照片排成竖直的 35mm 胶片条（照相亭「精选照片条」橱窗那样）。
///
/// 普通照片每 4 张拼成一条正片（`FilmStrips`），齿孔透出光台的光，片边印着橙色的胶卷名与帧号；
/// 大头贴直接摆整条成片。月份之间夹一张打字机纸条。「洗一洗」重新打乱顺序与角度；
/// 「正片 / 负片」切换整张光台；鼠标停在某一格上会出现放大镜（里面永远是正片）。
struct FilmLightTable: View {
    let records: [PhotoRecord]
    let libraryIsEmpty: Bool
    @State private var negative = false
    @State private var shuffleSeed: UInt64 = 0

    var body: some View {
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let items = Self.items(FilmStrips.make(from: records), shuffleSeed: shuffleSeed)
        ZStack {
            WalnutDesk()
            GeometryReader { geo in
                let stripHeight = max(260, min(geo.size.height - 150, 640))
                let scale = stripHeight / FilmGeometry.length(frames: 4)
                Lightbox {
                    if libraryIsEmpty {
                        TypedSlip(text: "光台上还没有底片 · 拍几张再来看", size: 14, tilt: -1.5)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(alignment: .center, spacing: 34) {
                                ForEach(items) { item in
                                    switch item {
                                    case .month(_, let title):
                                        TypedSlip(text: title, size: 12, tilt: -3)
                                            .padding(.horizontal, 4)
                                    case .strip(let strip, let seed):
                                        StripOnTable(strip: strip, records: byID, scale: scale, negative: negative, seed: seed)
                                    }
                                }
                            }
                            .padding(.horizontal, 56)
                            .frame(minHeight: geo.size.height - 80)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 72)
            }
            VStack {
                Spacer()
                HStack(spacing: 14) {
                    WashButton {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.74)) {
                            shuffleSeed = SeededRandom.makeSeed()
                        }
                        SoundPlayer.shared.play(.cardSlide)
                    }
                    PositiveNegativeToggle(negative: $negative)
                }
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - 排布

    enum TableItem: Identifiable {
        case month(String, String)
        case strip(FilmStrip, UInt64)

        var id: String {
            switch self {
            case .month(let key, _): "month-\(key)"
            case .strip(let strip, _): strip.id
            }
        }
    }

    private static let monthNames = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

    /// 新的月份在左；每个月一张纸条，后面是这个月的胶片条（新的在前，洗过就按 seed 打乱）。
    static func items(_ strips: [FilmStrip], shuffleSeed: UInt64) -> [TableItem] {
        var months: [String: [FilmStrip]] = [:]
        for strip in strips {
            months[strip.monthKey, default: []].append(strip)
        }
        var result: [TableItem] = []
        for key in months.keys.sorted(by: >) {
            var list = (months[key] ?? []).sorted { $0.startDate > $1.startDate }
            if shuffleSeed != 0 {
                var rng = SeededRandom(seed: shuffleSeed ^ stableHash(key))
                list.shuffle(using: &rng)
            }
            result.append(.month(key, monthTitle(key)))
            for strip in list {
                result.append(.strip(strip, stableHash(strip.id) ^ shuffleSeed))
            }
        }
        return result
    }

    static func monthTitle(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else { return key }
        return "\(parts[0]) · \(monthNames[month - 1])"
    }

    /// FNV-1a（稳定，不随启动变化）。
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

// MARK: - 35mm 胶片的尺寸（毫米）

enum FilmGeometry {
    static let width: CGFloat = 35
    static let frameWidth: CGFloat = 24
    static let frameHeight: CGFloat = 36
    static let pitch: CGFloat = 38
    static let lead: CGFloat = 2
    static let holeWidth: CGFloat = 2.8
    static let holeHeight: CGFloat = 1.98
    static let holePitch: CGFloat = 4.75
    static let holeCenterFromEdge: CGFloat = 2.4

    static func length(frames: Int) -> CGFloat {
        CGFloat(max(frames, 1)) * pitch + lead * 2
    }

    static var sideMargin: CGFloat { (width - frameWidth) / 2 }
}

// MARK: - 光台上的一条

private struct StripOnTable: View {
    let strip: FilmStrip
    let records: [UUID: PhotoRecord]
    let scale: CGFloat
    let negative: Bool
    let seed: UInt64
    @State private var loupeActive = false

    init(strip: FilmStrip, records: [UUID: PhotoRecord], scale: CGFloat, negative: Bool, seed: UInt64) {
        self.strip = strip
        self.records = records
        self.scale = scale
        self.negative = negative
        self.seed = seed
    }

    var body: some View {
        let tilt = (Double((seed >> 12) & 0xFF) / 255 - 0.5) * 6
        let dy = (CGFloat((seed >> 28) & 0xFF) / 255 - 0.5) * 32
        Group {
            switch strip.kind {
            case .roll:
                RollStrip(strip: strip, records: records, scale: scale, negative: negative, loupeActive: $loupeActive)
            case .booth:
                BoothStrip(strip: strip, records: records, height: FilmGeometry.length(frames: 4) * scale, loupeActive: $loupeActive)
            }
        }
        .rotationEffect(.degrees(tilt))
        .offset(y: dy)
        .zIndex(loupeActive ? 10 : 0)
    }
}

/// 一条 35mm 正片：片基 + 齿孔（挖空，透出光台）+ 橙色片边字 + 每格一张照片。
private struct RollStrip: View {
    let strip: FilmStrip
    let records: [UUID: PhotoRecord]
    let scale: CGFloat
    let negative: Bool
    @Binding var loupeActive: Bool

    var body: some View {
        let k = scale
        let count = strip.frames.count
        let size = CGSize(width: FilmGeometry.width * k, height: FilmGeometry.length(frames: count) * k)
        let frameSize = CGSize(width: FilmGeometry.frameWidth * k, height: FilmGeometry.frameHeight * k)
        ZStack(alignment: .topLeading) {
            FilmBase(frames: count, scale: k, negative: negative, edgeText: edgeText, firstFrame: strip.firstFrameNumber)
                .frame(width: size.width, height: size.height)
            ForEach(Array(strip.frames.enumerated()), id: \.offset) { index, frame in
                if let record = records[frame.recordID] {
                    FilmFrameCell(record: record, negativeIndex: frame.negativeIndex, size: frameSize, negative: negative, loupeActive: $loupeActive)
                        .offset(
                            x: FilmGeometry.sideMargin * k,
                            y: (FilmGeometry.lead + CGFloat(index) * FilmGeometry.pitch + (FilmGeometry.pitch - FilmGeometry.frameHeight) / 2) * k
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.28), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: Color(hex: 0x5A3A1A, opacity: 0.18), radius: 10, x: 3, y: 7)
    }

    private var edgeText: String {
        let english = FilmCatalog.stock(id: strip.stockID).englishName.uppercased()
        return "NOCCHI · \(english.isEmpty ? strip.stockName : english)"
    }
}

/// 片基：圆角长条，齿孔挖空；片边印胶卷名与帧号（橙色打字机字）。
private struct FilmBase: View {
    let frames: Int
    let scale: CGFloat
    let negative: Bool
    let edgeText: String
    let firstFrame: Int

    var body: some View {
        Canvas { context, size in
            let k = scale
            let base = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.2 * k)
            context.fill(base, with: .color(negative ? Color(hex: 0x9A5427, opacity: 0.92) : Color(hex: 0x1A1512)))
            // 片基上一层极淡的光泽
            context.fill(base, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.06), .clear, Color.white.opacity(0.04)]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ))
            // 齿孔：挖空
            var holes = Path()
            var y = FilmGeometry.lead * k * 0.6
            let holeW = FilmGeometry.holeWidth * k
            let holeH = FilmGeometry.holeHeight * k
            while y + holeH < size.height {
                for cx in [FilmGeometry.holeCenterFromEdge * k, size.width - FilmGeometry.holeCenterFromEdge * k] {
                    holes.addRoundedRect(in: CGRect(x: cx - holeW / 2, y: y, width: holeW, height: holeH), cornerSize: CGSize(width: 0.45 * k, height: 0.45 * k))
                }
                y += FilmGeometry.holePitch * k
            }
            var punch = context
            punch.blendMode = .destinationOut
            punch.fill(holes, with: .color(.black))
            // 片边字：右侧一行胶卷名，左侧帧号
            let orange = Color(hex: 0xE8892F).opacity(negative ? 0.95 : 0.9)
            let fontSize = max(5.5, 1.6 * k)
            var edge = context
            edge.translateBy(x: size.width - (FilmGeometry.holeCenterFromEdge + FilmGeometry.holeWidth / 2 + 0.55) * k, y: FilmGeometry.lead * k + 6)
            edge.rotate(by: .degrees(90))
            edge.draw(Text(edgeText).font(.custom("American Typewriter", size: fontSize)).foregroundColor(orange), at: .zero, anchor: .bottomLeading)
            for index in 0..<frames {
                let number = firstFrame + index
                var label = context
                let top = (FilmGeometry.lead + CGFloat(index) * FilmGeometry.pitch + FilmGeometry.pitch * 0.62) * k
                label.translateBy(x: (FilmGeometry.holeCenterFromEdge + FilmGeometry.holeWidth / 2 + 0.55) * k, y: top)
                label.rotate(by: .degrees(90))
                label.draw(Text("\(number)  ▸ \(number)A").font(.custom("American Typewriter", size: fontSize)).foregroundColor(orange), at: .zero, anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 胶片上的一格。负片 = 反色 + 橙色片基色罩；放大镜里永远是正片。
private struct FilmFrameCell: View {
    let record: PhotoRecord
    let negativeIndex: Int
    let size: CGSize
    let negative: Bool
    @Binding var loupeActive: Bool
    @State private var image: NSImage?
    @State private var hoverPoint: CGPoint?

    init(record: PhotoRecord, negativeIndex: Int, size: CGSize, negative: Bool, loupeActive: Binding<Bool>) {
        self.record = record
        self.negativeIndex = negativeIndex
        self.size = size
        self.negative = negative
        self._loupeActive = loupeActive
    }

    private var url: URL? {
        guard negativeIndex >= 0, negativeIndex < record.negatives.count else { return AlbumActions.imageURL(record) }
        return Services.library.negativeURL(record.negatives[negativeIndex])
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: 0x2A231E))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .modifier(NegativeLook(enabled: negative))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 0.8, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let hoverPoint, let image {
                LoupeView(image: image, frameSize: size, point: hoverPoint)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverPoint = location
                if !loupeActive { loupeActive = true }
            case .ended:
                hoverPoint = nil
                loupeActive = false
            }
        }
        .onTapGesture(count: 2) { AlbumActions.open(record) }
        .contextMenu { AlbumContextMenu(record: record) }
        .help("\(record.indexTitle) · \(record.dateText)")
        .task(id: url?.path ?? "") {
            guard let url else { return }
            image = await ThumbnailCache.shared.load(url, version: record.editedAt, maxPixel: 640)
        }
    }
}

private struct NegativeLook: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .colorInvert()
                .colorMultiply(Color(hex: 0xF0A867))
                .saturation(0.85)
        } else {
            content
        }
    }
}

/// 放大镜：黄铜 / 黑色外圈（`Loupe` 渲染图）+ 2.2 倍的正片，跟着鼠标。
private struct LoupeView: View {
    let image: NSImage
    let frameSize: CGSize
    let point: CGPoint
    private let zoom: CGFloat = 2.2
    private let diameter: CGFloat = 156

    var body: some View {
        let lens = diameter * 0.68
        ZStack {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: frameSize.width * zoom, height: frameSize.height * zoom)
                .clipped()
                .offset(x: (frameSize.width / 2 - point.x) * zoom, y: (frameSize.height / 2 - point.y) * zoom)
                .frame(width: lens, height: lens)
                .background(Color(hex: 0x2A231E))
                .clipShape(Circle())
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: lens, height: lens)
            if BundledImage.has("Loupe") {
                Image("Loupe")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: diameter, height: diameter)
            } else {
                Circle()
                    .strokeBorder(Color(hex: 0x161616), lineWidth: (diameter - lens) / 2)
                    .overlay(Circle().stroke(Color(white: 0.85), lineWidth: 1.2).frame(width: lens + 2, height: lens + 2))
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 2)
        .shadow(color: .black.opacity(0.25), radius: 16, x: 6, y: 12)
        .position(x: point.x, y: point.y)
        .allowsHitTesting(false)
    }
}

/// 一整条大头贴（成片本身就是一条），和胶片条一样高。
private struct BoothStrip: View {
    let strip: FilmStrip
    let records: [UUID: PhotoRecord]
    let height: CGFloat
    @Binding var loupeActive: Bool

    var body: some View {
        if let first = strip.frames.first, let record = records[first.recordID] {
            let aspect = max(0.1, record.layout.aspect)
            AlbumThumbnail(record: record, maxPixel: 900)
                .frame(width: height * aspect, height: height)
                .shadow(color: .black.opacity(0.3), radius: 1.2, x: 0.6, y: 1)
                .shadow(color: Color(hex: 0x5A3A1A, opacity: 0.2), radius: 10, x: 3, y: 7)
                .onTapGesture(count: 2) { AlbumActions.open(record) }
                .contextMenu { AlbumContextMenu(record: record) }
                .help("\(record.indexTitle) · \(record.dateText)")
        }
    }
}

// MARK: - 光台与桌面

/// 光台：铝边圆角框 + 暖白发光面 + 每 24pt 一条淡网格线，向桌面溢出一圈暖光。
private struct Lightbox<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RadialGradient(colors: [Palette.lightbox, Palette.lightboxEdge], center: .center, startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.7))
                LightboxGrid()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                content
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color(white: 0.93), Color(white: 0.62), Color(white: 0.85), Color(white: 0.55)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 4
                    )
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    .padding(4)
            }
            .shadow(color: Color(hex: 0xFFDFA0, opacity: 0.45), radius: 34)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
    }
}

private struct LightboxGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 24
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += 24
            }
            var y: CGFloat = 24
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 24
            }
            context.stroke(path, with: .color(Palette.ink.opacity(0.04)), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

/// 深色胡桃木桌面。
private struct WalnutDesk: View {
    var body: some View {
        ZStack {
            Palette.walnutDeep
            if BundledImage.has("WoodTexture") {
                Image("WoodTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.55)
            }
            RadialGradient(colors: [.clear, Color.black.opacity(0.45)], center: .center, startRadius: 200, endRadius: 900)
        }
    }
}

// MARK: - 按键

/// 「洗一洗」：象牙白的复古按键。
private struct WashButton: View {
    let action: () -> Void
    @State private var hovering = false

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .bold))
                Text("洗一洗")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Palette.ivoryLight, Palette.ivory], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 0.8).padding(0.6))
            .overlay(Capsule().stroke(Palette.walnutDeep.opacity(0.4), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.4), radius: 0.8, y: 1)
            .shadow(color: .black.opacity(hovering ? 0.36 : 0.26), radius: hovering ? 10 : 6, y: hovering ? 6 : 3)
            .scaleEffect(hovering ? 1.03 : 1)
        }
        .buttonStyle(PressDownStyle())
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovering = inside }
        }
        .help("重新打乱光台上的胶片条")
    }
}

/// 按下去时略微下沉。
private struct PressDownStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 正片 / 负片切换（两段的象牙白托盘）。
private struct PositiveNegativeToggle: View {
    @Binding var negative: Bool
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            segment("正片", selected: !negative) { negative = false }
            segment("负片", selected: negative) { negative = true }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Palette.ivory.shadow(.inner(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)))
        )
        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { action() }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 0.8, y: 0.8)
                            .matchedGeometryEffect(id: "posneg", in: namespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
