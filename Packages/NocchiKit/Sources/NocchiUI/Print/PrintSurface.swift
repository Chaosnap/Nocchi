import CoreGraphics
import NocchiKit
import SwiftUI

/// 一张即显相片的纸面（两端共用）。
///
/// 层次（从下到上）：
/// 1. 纸张：带年代感的暖白渐变 + 纤维纹理 + 极细颗粒 + 边缘做旧
/// 2. 底边药包的细微隆起（方形即显相纸）
/// 3. 图像窗口：显影动画、窗口内凹的阴影与发丝边
/// 4. 光面涂层：随位置移动的高光（只在屏幕上，不进成片）
/// 5. 题字、日期、手写
/// 6. 纸边倒角与整体卷曲明暗
///
/// 几何与字体和 `PhotoComposer` 一致：显影完成时与导出的成片相同（光面高光除外）。
public struct PrintSurface: View {
    public let record: PhotoRecord
    public let images: [CGImage]
    public let visuals: [DevelopmentVisual]
    public let paper: PaperStyle
    public let width: CGFloat
    public var liveStroke: InkStroke?
    /// 光面高光的位置（0…1，随相片在屏幕上的位置变化）。
    public var sheen: CGPoint
    public var showsGloss: Bool

    public init(
        record: PhotoRecord,
        images: [CGImage],
        visuals: [DevelopmentVisual],
        paper: PaperStyle,
        width: CGFloat,
        liveStroke: InkStroke? = nil,
        sheen: CGPoint = CGPoint(x: 0.32, y: 0.22),
        showsGloss: Bool = true
    ) {
        self.record = record
        self.images = images
        self.visuals = visuals
        self.paper = paper
        self.width = width
        self.liveStroke = liveStroke
        self.sheen = sheen
        self.showsGloss = showsGloss
    }

    public var body: some View {
        let layout = record.layout
        let size = layout.size(forWidth: width)
        let corner = layout.cornerRadius * width / layout.paperSize.width
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let tones = PaperTones(paper)

        ZStack(alignment: .topLeading) {
            // 1. 纸张
            shape.fill(LinearGradient(colors: [tones.top, tones.bottom], startPoint: .top, endPoint: .bottom))
            Image("PaperTexture")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .blendMode(.multiply)
                .opacity(paper.isDark ? 0.12 : 0.42)
                .allowsHitTesting(false)
            Image(decorative: PaperGrain.shared, scale: 2)
                .resizable(resizingMode: .tile)
                .frame(width: size.width, height: size.height)
                .blendMode(paper.isDark ? .screen : .multiply)
                .opacity(paper.isDark ? 0.18 : 0.55)
                .allowsHitTesting(false)
            RadialGradient(colors: [Color.clear, tones.age], center: .center, startRadius: size.width * 0.42, endRadius: size.height * 0.78)
                .allowsHitTesting(false)

            // 2. 药包隆起
            if record.format == .instantSquare {
                let ridgeY = PrintGeometry.podRidgeY(layout: layout, width: width)
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(paper.isDark ? 0.25 : 0.05)).frame(height: max(0.5, width * 0.003))
                    Rectangle().fill(Color.white.opacity(paper.isDark ? 0.05 : 0.45)).frame(height: max(0.5, width * 0.003))
                }
                .frame(width: size.width * 0.9)
                .offset(x: size.width * 0.05, y: ridgeY)
                .allowsHitTesting(false)
            }

            // 3. 图像窗口
            ForEach(Array(layout.windows.enumerated()), id: \.offset) { item in
                let rect = layout.scaled(item.element, toWidth: width)
                ZStack {
                    DevelopingWindow(
                        image: item.offset < images.count ? images[item.offset] : nil,
                        visual: item.offset < visuals.count ? visuals[item.offset] : .developed,
                        offset: item.offset < record.frameOffsets.count ? record.frameOffsets[item.offset] : .zero,
                        size: rect.size
                    )
                    WindowRecess(size: rect.size, darkPaper: paper.isDark)
                    if showsGloss {
                        Gloss(sheen: sheen)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .clipped()
                .offset(x: rect.minX, y: rect.minY)
            }

            // 5. 题字、日期、手写
            PrintCaption(
                layout: layout,
                paperWidth: width,
                caption: record.caption,
                date: record.showsDate ? record.dateText : nil,
                ink: Color(nocchi: paper.inkRGB)
            )
            PrintInk(strokes: record.strokes + (liveStroke.map { [$0] } ?? []), paperWidth: width)
                .frame(width: size.width, height: size.height)

            // 6. 卷曲明暗
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0), Color.black.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(paper.isDark ? 0.18 : 0.85), Color.white.opacity(0.08), Color.black.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(0.6, width * 0.004)
            )
        )
    }
}

/// 纸张的几组色调。
struct PaperTones {
    let top: Color
    let bottom: Color
    let age: Color

    init(_ paper: PaperStyle) {
        let base = paper.paperRGB
        if paper.isDark {
            top = Color(nocchi: base * 1.08)
            bottom = Color(nocchi: base * 0.92)
            age = Color.black.opacity(0.25)
        } else {
            let warm = RGB(0.86, 0.80, 0.68)
            top = Color(nocchi: ColorMath.clamp01(base * 1.012))
            bottom = Color(nocchi: ColorMath.mix(base, warm, 0.10))
            age = Color(nocchi: warm * 0.9, opacity: 0.22)
        }
    }
}

/// 显影中的图像：乳灰底 → 蓝色先出来 → 对比度和饱和度慢慢上来 → 最后暖色。
struct DevelopingWindow: View {
    let image: CGImage?
    let visual: DevelopmentVisual
    let offset: FrameOffset
    let size: CGSize

    var body: some View {
        ZStack {
            Color(white: 0.12)
            Color(red: 0.78, green: 0.79, blue: 0.74)
                .opacity(1 - visual.imageOpacity)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .offset(x: offset.dx * size.width, y: offset.dy * size.height)
                    .saturation(visual.saturation)
                    .contrast(visual.contrast)
                    .brightness(visual.brightness)
                    .colorMultiply(Color(red: visual.red, green: visual.green, blue: visual.blue))
                    .blur(radius: visual.blurFraction * size.width, opaque: true)
                    .opacity(visual.imageOpacity)
            }
            Color(red: 0.62, green: 0.74, blue: 0.74)
                .opacity(visual.hazeOpacity)
                .blendMode(.screen)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// 窗口内凹：相纸边框在图像上投下的细影，加一圈发丝边。导出成片里有同样的处理。
struct WindowRecess: View {
    let size: CGSize
    let darkPaper: Bool

    var body: some View {
        let depth = PrintGeometry.recessDepth(windowWidth: size.width)
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.26), Color.clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: depth / size.height))
            LinearGradient(colors: [Color.black.opacity(0.16), Color.clear], startPoint: .leading, endPoint: UnitPoint(x: depth / size.width, y: 0.5))
            LinearGradient(colors: [Color.clear, Color.white.opacity(0.14)], startPoint: UnitPoint(x: 0.5, y: 1 - depth / size.height), endPoint: .bottom)
            Rectangle()
                .strokeBorder(Color.black.opacity(darkPaper ? 0.45 : 0.22), lineWidth: max(0.5, size.width * 0.0035))
        }
        .allowsHitTesting(false)
    }
}

/// 光面涂层：一道斜向的柔光和一块高光，位置随 `sheen` 移动。
struct Gloss: View {
    let sheen: CGPoint

    var body: some View {
        let s = min(max(Double(sheen.x) * 0.6 + 0.2, 0.12), 0.88)
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0), location: s - 0.12),
                    .init(color: Color.white.opacity(0.15), location: s),
                    .init(color: Color.white.opacity(0), location: s + 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0)],
                center: UnitPoint(x: sheen.x, y: sheen.y),
                startRadius: 0,
                endRadius: 140
            )
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

/// 白边上的题字与日期（与 `PhotoComposer` 同字体、同位置）。
struct PrintCaption: View {
    let layout: PaperLayout
    let paperWidth: CGFloat
    let caption: String?
    let date: String?
    let ink: Color

    var body: some View {
        let area = layout.scaled(layout.captionArea, toWidth: paperWidth)
        let captionSize = PhotoComposer.captionFontSize(paperWidth: paperWidth, layout: layout)
        let dateSize = PhotoComposer.dateFontSize(paperWidth: paperWidth, layout: layout)
        VStack(spacing: captionSize * 0.12) {
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom(PhotoComposer.captionFontName, size: captionSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .opacity(0.88)
            }
            if let date {
                Text(date)
                    .font(.custom(PhotoComposer.dateFontName, size: dateSize))
                    .tracking(dateSize * 0.08)
                    .opacity(0.6)
            }
        }
        .foregroundStyle(ink)
        .frame(width: area.width, height: area.height)
        .offset(x: area.minX, y: area.minY)
        .allowsHitTesting(false)
    }
}

/// 手写笔画。
struct PrintInk: View {
    let strokes: [InkStroke]
    let paperWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                let color = Color(nocchi: RGB(hex: stroke.color) ?? RGB(0.17, 0.16, 0.16), opacity: 0.92)
                let points = stroke.points
                if points.count == 1, let p = points.first {
                    let r = p.w * paperWidth / 2
                    context.fill(Path(ellipseIn: CGRect(x: p.x * paperWidth - r, y: p.y * paperWidth - r, width: r * 2, height: r * 2)), with: .color(color))
                    continue
                }
                guard points.count > 1 else { continue }
                for index in 1..<points.count {
                    let a = points[index - 1]
                    let b = points[index]
                    var path = Path()
                    path.move(to: CGPoint(x: a.x * paperWidth, y: a.y * paperWidth))
                    path.addLine(to: CGPoint(x: b.x * paperWidth, y: b.y * paperWidth))
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: (a.w + b.w) / 2 * paperWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 预先生成的极细纸张颗粒（平铺用）。
enum PaperGrain {
    static let shared: CGImage = {
        let size = 192
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        var rng = SeededRandom(seed: 0x9A9E2)
        for _ in 0..<2600 {
            let x = rng.range(0, Double(size))
            let y = rng.range(0, Double(size))
            let shade = rng.range(0.55, 0.85)
            let alpha = rng.range(0.05, 0.16)
            ctx.setFillColor(CGColor(srgbRed: shade, green: shade * 0.98, blue: shade * 0.94, alpha: alpha))
            let d = rng.range(0.6, 1.4)
            ctx.fill(CGRect(x: x, y: y, width: d, height: d))
        }
        return ctx.makeImage()!
    }()
}

public extension Color {
    /// 从 NocchiKit 的 RGB 构造 sRGB 颜色。
    init(nocchi rgb: RGB, opacity: Double = 1) {
        let c = ColorMath.clamp01(rgb)
        self.init(.sRGB, red: Double(c.x), green: Double(c.y), blue: Double(c.z), opacity: opacity)
    }
}
