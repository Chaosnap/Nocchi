import NocchiKit
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// 卡片盒用到的颜色（和 App 里的 `Palette` 同一套值）。
enum CardInk {
    static let paper = Color(cardHex: 0xF4F0E6)
    static let photoWell = Color(cardHex: 0xE9E3D6)
    static let ink = Color(cardHex: 0x2E2924)
    static let inkSoft = Color(cardHex: 0x7A6F64)
    static let hairline = Color(cardHex: 0xD8CFBF)
    static let accent = Color(cardHex: 0xC4593B)
    static let rule = Color(cardHex: 0xB23A2A)
    static let ruleBlue = Color(cardHex: 0x6F8FB8)
    static let ivory = Color(cardHex: 0xECE6DA)
    static let ivoryLight = Color(cardHex: 0xF2EEE6)
}

extension Color {
    init(cardHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// App 资源目录（`Shared/Art.xcassets`）里有没有这张图。
@MainActor
enum BundledArt {
    private static var known: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let cached = known[name] { return cached }
        #if canImport(AppKit)
        let found = NSImage(named: name) != nil
        #elseif canImport(UIKit)
        let found = UIImage(named: name) != nil
        #else
        let found = false
        #endif
        known[name] = found
        return found
    }
}

// MARK: - 盒子

/// 一张卡片盒渲染图（和热点同一画布），缺图时画一个简单的木盒。
struct BoxArt: View {
    let name: String
    let stage: CardBoxStage
    let fallback: Bool

    var body: some View {
        Group {
            if BundledArt.has(name) {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else if fallback {
                FallbackBox()
            } else {
                Color.clear
            }
        }
        .frame(width: stage.imageFrame.width, height: stage.imageFrame.height)
        .position(x: stage.imageFrame.midX, y: stage.imageFrame.midY)
    }
}

/// 渲染图缺失时的退路：一只朴素的浅木盒。
private struct FallbackBox: View {
    var body: some View {
        GeometryReader { geo in
            let b = CardBoxHotspots.boxBounds
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(cardHex: 0xF0E9DC), Color(cardHex: 0xD9D0C0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: b.width * w * 0.86, height: b.height * h * 0.5)
                    .position(x: b.midX * w, y: (b.minY + b.height * 0.36) * h)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(cardHex: 0xE2B079), Color(cardHex: 0xC98E52)], startPoint: .top, endPoint: .bottom))
                    .frame(width: b.width * w, height: b.height * h * 0.48)
                    .position(x: b.midX * w, y: (b.minY + b.height * 0.74) * h)
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 4, y: 10)
            }
        }
    }
}

/// 暖米色的无缝背景（和渲染里的地面一致，盒子周围略亮）。
struct CardBoxBackdrop: View {
    let stage: CardBoxStage

    var body: some View {
        let w = max(stage.size.width, 1)
        let h = max(stage.size.height, 1)
        let b = CardBoxHotspots.boxBounds
        let glow = stage.point(CGPoint(x: b.midX, y: b.midY))
        ZStack {
            Color(cardHex: 0xE4DED3)
            RadialGradient(
                colors: [Color(cardHex: 0xF5F0E7), Color(cardHex: 0xE4DED3, opacity: 0)],
                center: UnitPoint(x: glow.x / w, y: glow.y / h),
                startRadius: 0,
                endRadius: max(w, h) * 0.66
            )
            LinearGradient(colors: [.clear, Color.black.opacity(0.06)], startPoint: .center, endPoint: .bottom)
        }
        .frame(width: w, height: h)
    }
}

// MARK: - 照片卡片

/// 一张照片索引卡：纸色卡片、照片在上、宋体标题与打字机副标题，左上方伸出字母小标签。
struct PhotoIndexCard: View {
    let record: PhotoRecord
    /// 卡片自己的小标签上印什么（和所在的分隔卡一样：「W」「2026」「11月」「11/24」）。
    let tabLabel: String
    let image: CGImage?
    let size: CGSize
    let lifted: Bool

    private let inset: CGFloat = 11

    var body: some View {
        let photoWidth = size.width - inset * 2
        let photoHeight = max(40, min(photoWidth, size.height - 80))
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(CardInk.photoWell)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: .black.opacity(0.2), radius: 1.2, x: 0.4, y: 0.8)
                        .padding(7)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(0.5)
                }
            }
            .frame(width: photoWidth, height: photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
            .padding(.top, inset)

            Rectangle()
                .fill(CardInk.rule.opacity(0.55))
                .frame(height: 0.8)
                .padding(.top, 10)

            Text(record.indexTitle)
                .font(.custom("Songti SC", size: 14).weight(.semibold))
                .foregroundStyle(CardInk.ink)
                .lineLimit(1)
                .padding(.top, 8)

            Text(subtitle)
                .font(.custom("American Typewriter", size: 10.5))
                .foregroundStyle(CardInk.inkSoft)
                .lineLimit(1)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(alignment: .top) {
            RuledLines(top: inset + photoHeight + 36, spacing: 17)
        }
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CardInk.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(CardInk.ink.opacity(0.13), lineWidth: 0.6)
        )
        .overlay(alignment: .topLeading) {
            LetterTab(letter: tabLabel)
                .offset(x: 18, y: -IndexTab.height + 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.26), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(lifted ? 0.3 : 0.2), radius: lifted ? 18 : 12, x: 4, y: lifted ? 14 : 9)
    }

    private var subtitle: String {
        var parts = [record.dateText]
        if let location = record.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            parts.append(location)
        }
        parts.append(record.stockName)
        return parts.joined(separator: " · ")
    }
}

/// 索引卡下半截的淡蓝横线。
private struct RuledLines: View {
    let top: CGFloat
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            var y = top
            var path = Path()
            while y < size.height - 6 {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(CardInk.ruleBlue.opacity(0.2)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// 索引卡标签的尺寸（标签上的字长时加宽）。
enum IndexTab {
    static let width: CGFloat = 36
    static let wideWidth: CGFloat = 54
    static let height: CGFloat = 21

    static func width(for label: String) -> CGFloat {
        label.count > 2 ? wideWidth : width
    }
}

/// 模切的索引卡标签：上窄下宽、上角圆，和卡片同一张纸；发丝描边、顶上一道纸边的亮线，
/// 字母用 Didot 粗体（像老档案柜索引卡上印的字）。
private struct LetterTab: View {
    let letter: String

    var body: some View {
        ZStack {
            IndexTabShape()
                .fill(LinearGradient(colors: [Color(cardHex: 0xFBF9F4), CardInk.paper], startPoint: .top, endPoint: .bottom))
            IndexTabShape()
                .stroke(CardInk.ink.opacity(0.16), lineWidth: 0.6)
            IndexTabShape()
                .inset(by: 1.2)
                .stroke(Color.white.opacity(0.85), lineWidth: 0.6)
                .mask { LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center) }
            Text(verbatim: letter)
                .font(.custom("Didot", size: letter.count > 2 ? 12.5 : 14).weight(.bold))
                .foregroundStyle(CardInk.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 5)
                .offset(y: 1)
        }
        .frame(width: IndexTab.width(for: letter), height: IndexTab.height)
    }
}

/// 上窄下宽、上角圆的标签外形（下边敞开，和卡片连在一起）。
struct IndexTabShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let taper = r.width * 0.09
        let radius = min(4.5, r.height * 0.3)
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY + inset))
        path.addLine(to: CGPoint(x: r.minX + taper, y: r.minY + radius))
        path.addQuadCurve(to: CGPoint(x: r.minX + taper + radius, y: r.minY), control: CGPoint(x: r.minX + taper, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - taper - radius, y: r.minY))
        path.addQuadCurve(to: CGPoint(x: r.maxX - taper, y: r.minY + radius), control: CGPoint(x: r.maxX - taper, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY + inset))
        return path
    }

    func inset(by amount: CGFloat) -> IndexTabShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

// MARK: - 分隔卡标签

/// 分隔卡标签上的热区：和标签面一样的斜四边形（稍微放大一点好点），悬停和点击都只认这一块。
/// 高亮、当前那一格的描边、有照片的小圆点画在 `TabLabels` 里（跟着标签面斜切）。
struct TabHotspot: View {
    let face: TabFace
    /// 这张分隔卡抬起来时标签的位移：热区往上补到抬满的位置（指针跟着标签往上移也不会掉下去）。
    var rise: CGSize = .zero

    /// 热区多边形（视图坐标）。
    var polygon: [CGPoint] { face.hitPolygon(rising: rise) }

    /// 热区的外接矩形。
    var box: CGRect {
        let xs = polygon.map(\.x)
        let ys = polygon.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: max(1, (xs.max() ?? 0) - minX), height: max(1, (ys.max() ?? 0) - minY))
    }

    var body: some View {
        let box = self.box
        Color.clear
            .frame(width: box.width, height: box.height)
            .contentShape(TabFaceShape(points: polygon.map { CGPoint(x: $0.x - box.minX, y: $0.y - box.minY) }))
    }
}

/// 一张分隔卡标签露出来的那一面在视图里的位置（由 `CardBoxHotspots.Tab.face` 换算）。
struct TabFace {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    init(slot: Int, stage: CardBoxStage) {
        let tab = CardBoxHotspots.tab(slot: slot)
        var points = tab.face.map { stage.point($0) }
        if points.count != 4 {
            // 热点数据缺了标签面：按标签中心估一个（渲染图 2000 像素宽时标签约 110 × 55 像素）。
            let c = stage.point(tab.center)
            let w = 110 * stage.pixelScale / 2
            let h = 55 * stage.pixelScale / 2
            points = [CGPoint(x: c.x - w, y: c.y - h), CGPoint(x: c.x + w, y: c.y - h), CGPoint(x: c.x + w, y: c.y + h), CGPoint(x: c.x - w, y: c.y + h)]
        }
        topLeft = points[0]
        topRight = points[1]
        bottomRight = points[2]
        bottomLeft = points[3]
    }

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// 标签面（视图坐标）。
    var path: Path {
        var path = Path()
        path.addLines(corners)
        path.closeSubpath()
        return path
    }

    /// 标签面的外接矩形。
    var bounds: CGRect {
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }

    var center: CGPoint {
        CGPoint(x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4, y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4)
    }

    var topCenter: CGPoint { CGPoint(x: (topLeft.x + topRight.x) / 2, y: (topLeft.y + topRight.y) / 2) }

    /// 标签下沿（分隔卡上沿）的中点。
    var bottomCenter: CGPoint { CGPoint(x: (bottomLeft.x + bottomRight.x) / 2, y: (bottomLeft.y + bottomRight.y) / 2) }

    /// 吊牌的位置：标签上沿中点再往上一点。
    var chipAnchor: CGPoint { CGPoint(x: topCenter.x, y: topCenter.y - 24) }

    /// 标签面自己的宽（沿分隔卡）和高（竖直方向）。
    var width: CGFloat { max(1, hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)) }
    var height: CGFloat { max(1, hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)) }

    /// 把 width × height 的矩形（左上原点）贴到标签面上的仿射变换（视图坐标）。
    var transform: CGAffineTransform {
        CGAffineTransform(
            a: (topRight.x - topLeft.x) / width,
            b: (topRight.y - topLeft.y) / width,
            c: (bottomLeft.x - topLeft.x) / height,
            d: (bottomLeft.y - topLeft.y) / height,
            tx: topLeft.x,
            ty: topLeft.y
        )
    }

    /// 热区：标签面绕中心放大 12%。
    var hitPolygon: [CGPoint] {
        let c = center
        return corners.map { CGPoint(x: c.x + ($0.x - c.x) * 1.12, y: c.y + ($0.y - c.y) * 1.12) }
    }

    /// 热区的外接矩形。
    var hitBox: CGRect {
        let xs = hitPolygon.map(\.x)
        let ys = hitPolygon.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: max(1, (xs.max() ?? 0) - minX), height: max(1, (ys.max() ?? 0) - minY))
    }
}

/// 由几个点围成的多边形（标签面的热区）。
struct TabFaceShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// 分隔卡标签上印的字（渲染图里的标签是空白的），以及悬停时的提亮、当前那一格的陶土橙描边、
/// 有照片时右上角的小圆点。
///
/// 一个 `Canvas` 画完全部标签：每张标签在自己的坐标里（宽 × 高，左上原点）排字，再整体斜切到标签面上，
/// 所以字和标签在同一个透视里，像印在纸上；每张都裁到「标签面减去挡在它前面的标签」，
/// 后面那张标签被前一张挡住的下角不会有字透出来。
struct TabLabels: View {
    let tabs: [CardTab]
    let mode: CardIndexMode
    let stage: CardBoxStage
    let hoveredKey: String?
    let activeKey: String?
    /// 被前面的标签挡住的地方不印字（平时如此）；抬起的那张标签不挡（前面的标签另外盖在它上面）。
    var occludedByFront = true

    var body: some View {
        Canvas { context, _ in
            let faces = (0..<CardIndex.slotCount).map { TabFace(slot: $0, stage: stage) }
            for tab in tabs where faces.indices.contains(tab.slot) {
                let face = faces[tab.slot]
                var ctx = context
                ctx.clip(to: face.path)
                if occludedByFront {
                    for front in faces.prefix(tab.slot) where front.bounds.intersects(face.bounds) {
                        ctx.clip(to: front.path, options: .inverse)
                    }
                }
                ctx.concatenate(face.transform)
                draw(tab, size: CGSize(width: face.width, height: face.height), in: &ctx)
            }
        }
        .frame(width: stage.size.width, height: stage.size.height)
        .allowsHitTesting(false)
    }

    private func draw(_ tab: CardTab, size: CGSize, in ctx: inout GraphicsContext) {
        let rect = CGRect(origin: .zero, size: size)
        if hoveredKey == tab.key {
            ctx.fill(Path(rect), with: .color(Color.white.opacity(0.3)))
        }
        if activeKey == tab.key {
            let width = max(1, size.height * 0.08)
            ctx.stroke(Path(rect.insetBy(dx: width / 2, dy: width / 2)), with: .color(CardInk.accent.opacity(0.9)), lineWidth: width)
        }
        // 字：首字母用 Futura 粗体（和以前烤在渲染图里的字一样），日期用 Futura 窄体好塞下「11/24」；放不下就缩小。
        let maxWidth = size.width * 0.8
        var fontSize = size.height * (mode == .letter ? 0.64 : 0.6)
        var text = ctx.resolve(label(tab, size: fontSize))
        let measured = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        if measured.width > maxWidth, measured.width > 0 {
            fontSize *= maxWidth / measured.width
            text = ctx.resolve(label(tab, size: fontSize))
        }
        ctx.draw(text, at: CGPoint(x: size.width / 2, y: size.height * 0.52), anchor: .center)
        if tab.count > 0 {
            let d = max(3.5, min(6.5, size.height * 0.26))
            let dot = CGRect(x: size.width - d - size.height * 0.12, y: size.height * 0.12, width: d, height: d)
            ctx.fill(Path(ellipseIn: dot), with: .color(CardInk.accent))
            ctx.stroke(Path(ellipseIn: dot), with: .color(Color.white.opacity(0.85)), lineWidth: 0.6)
        }
    }

    private func label(_ tab: CardTab, size: CGFloat) -> Text {
        let font: Font = mode == .letter ? .custom("Futura-Bold", size: size) : .custom("Futura-CondensedExtraBold", size: size)
        return Text(verbatim: tab.label)
            .font(font)
            .foregroundStyle(CardInk.ink.opacity(tab.count > 0 ? 0.88 : 0.42))
    }
}

/// 悬停在分隔卡标签上时的小吊牌：Didot 的「W」/「2026 年 11 月」+ 打字机小字「3 张」/「空」，
/// 下面一个小尖角指着标签。
struct TabChip: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: title)
                    .font(.custom("Didot", size: title.count > 2 ? 14.5 : 17).weight(.bold))
                    .foregroundStyle(CardInk.ink)
                    .fixedSize()
                Rectangle()
                    .fill(CardInk.rule.opacity(0.5))
                    .frame(width: 0.8, height: 11)
                Group {
                    if count > 0 {
                        Text("\(count) 张")
                    } else {
                        Text("空")
                    }
                }
                .font(.custom("American Typewriter", size: 11.5))
                .foregroundStyle(count > 0 ? CardInk.ink : CardInk.inkSoft)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(LinearGradient(colors: [Color(cardHex: 0xFBF9F4), CardInk.paper], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(CardInk.ink.opacity(0.16), lineWidth: 0.6)
            )
            ChipPointer()
                .fill(CardInk.paper)
                .overlay(ChipPointer().stroke(CardInk.ink.opacity(0.16), lineWidth: 0.6))
                .frame(width: 10, height: 5)
                .offset(y: -0.8)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 0.8, y: 0.8)
        .shadow(color: .black.opacity(0.16), radius: 6, y: 4)
        .fixedSize()
    }
}

/// 吊牌下面的小尖角。
private struct ChipPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - 摊开区

/// 「全部放回」「重新叠好」：象牙白的复古按键。
struct PutBackButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    init(title: String = String(localized: "全部放回"), symbol: String = "arrow.uturn.backward", action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(CardInk.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [CardInk.ivoryLight, CardInk.ivory], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 0.8).padding(0.6))
            .overlay(Capsule().stroke(CardInk.hairline, lineWidth: 0.6))
            .shadow(color: .black.opacity(0.24), radius: 0.8, y: 0.8)
            .shadow(color: .black.opacity(hovering ? 0.2 : 0.12), radius: hovering ? 8 : 5, y: hovering ? 5 : 3)
            .scaleEffect(hovering ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovering = inside }
        }
        .help(title == String(localized: "全部放回") ? String(localized: "把摊开的卡片全部放回盒子") : String(localized: "让拖开的卡片回到那一叠"))
    }
}

/// 扇形下面的一行打字机小字。
struct SpreadCaption: View {
    let text: String
    let more: Bool

    var body: some View {
        Text(more ? String(localized: "\(text) · 左右拖动翻看") : text)
            .font(.custom("American Typewriter", size: 11.5))
            .foregroundStyle(CardInk.inkSoft)
            .tracking(0.4)
            .fixedSize()
    }
}

/// 盒子是空的：一张打字机索引卡。
struct EmptyBoxCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡片盒还是空的")
                .font(.custom("Songti SC", size: 17).weight(.semibold))
                .foregroundStyle(CardInk.ink)
            Rectangle()
                .fill(CardInk.rule.opacity(0.55))
                .frame(height: 0.8)
            Text("拍下的照片会按题字的首字母放进盒子里。\n把鼠标移到刘海，按「屏幕快门」或「自拍」拍第一张。")
                .font(.custom("American Typewriter", size: 12))
                .foregroundStyle(CardInk.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(CardInk.paper))
        .rotationEffect(.degrees(-1.5))
        .shadow(color: .black.opacity(0.24), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 14, x: 4, y: 10)
    }
}
