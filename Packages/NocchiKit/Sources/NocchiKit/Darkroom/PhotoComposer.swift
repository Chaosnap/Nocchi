import CoreGraphics
import CoreText
import Foundation

/// 一张成片需要的全部内容。
public struct PrintSpec {
    public var layout: PaperLayout
    public var paper: PaperStyle
    /// 每个窗口一张（已含色块）。
    public var images: [CGImage]
    public var frameOffsets: [FrameOffset]
    public var strokes: [InkStroke]
    public var caption: String?
    public var dateText: String?
    public var widthPixels: Int

    public init(
        layout: PaperLayout,
        paper: PaperStyle,
        images: [CGImage],
        frameOffsets: [FrameOffset] = [],
        strokes: [InkStroke] = [],
        caption: String? = nil,
        dateText: String? = nil,
        widthPixels: Int
    ) {
        self.layout = layout
        self.paper = paper
        self.images = images
        self.frameOffsets = frameOffsets
        self.strokes = strokes
        self.caption = caption
        self.dateText = dateText
        self.widthPixels = widthPixels
    }
}

/// 用 Core Graphics 把底片、白边、手写和题字合成一张「带白边的成片」。
///
/// 界面上的 SwiftUI 相纸使用同一套 `PaperLayout` 几何和同样的字体，导出结果与屏幕上一致。
public enum PhotoComposer {
    /// 题字字体：自然的钢笔手写体（macOS / iOS 都自带；中文字形由系统自动回落）。
    public static let captionFontName = "BradleyHandITCTT-Bold"
    /// 日期字体：复古打字机体。
    public static let dateFontName = "AmericanTypewriter"

    /// 题字字号（相对相纸宽度）。
    public static func captionFontSize(paperWidth: CGFloat, layout: PaperLayout) -> CGFloat {
        let area = layout.scaled(layout.captionArea, toWidth: paperWidth)
        return min(area.height * 0.42, paperWidth * 0.062)
    }

    public static func dateFontSize(paperWidth: CGFloat, layout: PaperLayout) -> CGFloat {
        captionFontSize(paperWidth: paperWidth, layout: layout) * 0.62
    }

    public static func render(_ spec: PrintSpec) -> CGImage? {
        let layout = spec.layout
        let width = CGFloat(max(64, spec.widthPixels))
        let height = (width / layout.aspect).rounded()
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        // 翻转成左上角原点，和 SwiftUI 一致。
        ctx.translateBy(x: 0, y: height)
        ctx.scaleBy(x: 1, y: -1)

        let s = width / layout.paperSize.width
        let paperRect = CGRect(x: 0, y: 0, width: width, height: height)
        let paperColor = spec.paper.paperRGB

        // 相纸：暖白渐变 + 极细颗粒 + 边缘做旧（与屏幕上的 PrintSurface 一致）
        let corner = layout.cornerRadius * s
        let paperPath = CGPath(roundedRect: paperRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.saveGState()
        ctx.addPath(paperPath)
        ctx.clip()
        drawPaper(ctx, rect: paperRect, paper: spec.paper)
        if layout.windows.count == 1, layout.captionArea.height > layout.paperSize.height * 0.12 {
            drawPodRidge(ctx, y: PrintGeometry.podRidgeY(layout: layout, width: width), width: width, dark: spec.paper.isDark)
        }
        ctx.restoreGState()

        // 图像窗口
        for (index, window) in layout.windows.enumerated() {
            let rect = layout.scaled(window, toWidth: width)
            ctx.saveGState()
            ctx.clip(to: rect)
            ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1))
            ctx.fill(rect)
            if index < spec.images.count {
                let image = spec.images[index]
                let offset = index < spec.frameOffsets.count ? spec.frameOffsets[index] : .zero
                var target = aspectFill(CGSize(width: image.width, height: image.height), into: rect)
                target = target.offsetBy(dx: CGFloat(offset.dx) * rect.width, dy: CGFloat(offset.dy) * rect.height)
                drawImage(ctx, image, in: target)
            }
            drawRecess(ctx, rect: rect)
            ctx.restoreGState()
            // 窗口发丝边
            ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: spec.paper.isDark ? 0.45 : 0.22))
            ctx.setLineWidth(max(1, rect.width * 0.0035))
            ctx.stroke(rect.insetBy(dx: max(0.5, rect.width * 0.00175), dy: max(0.5, rect.width * 0.00175)))
        }

        // 题字与日期
        let caption = layout.scaled(layout.captionArea, toWidth: width)
        let ink = spec.paper.inkRGB
        if let text = spec.caption, !text.isEmpty {
            let size = captionFontSize(paperWidth: width, layout: layout)
            let baselineY = spec.dateText == nil ? caption.midY + size * 0.35 : caption.minY + caption.height * 0.5
            drawText(ctx, text, fontName: captionFontName, size: size, color: ink, centerX: caption.midX, baselineY: baselineY, maxWidth: caption.width, alpha: 0.88)
        }
        if let date = spec.dateText {
            let size = dateFontSize(paperWidth: width, layout: layout)
            let baselineY = (spec.caption?.isEmpty == false) ? caption.minY + caption.height * 0.86 : caption.midY + size * 0.35
            drawText(ctx, date, fontName: dateFontName, size: size, color: ink, centerX: caption.midX, baselineY: baselineY, maxWidth: caption.width, alpha: 0.6, tracking: size * 0.08)
        }

        // 手写
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for stroke in spec.strokes {
            let color = RGB(hex: stroke.color) ?? ink
            ctx.setStrokeColor(cgColor(color))
            ctx.setFillColor(cgColor(color))
            let points = stroke.points
            if points.count == 1, let p = points.first {
                let r = CGFloat(p.w) * width / 2
                ctx.fillEllipse(in: CGRect(x: CGFloat(p.x) * width - r, y: CGFloat(p.y) * width - r, width: r * 2, height: r * 2))
                continue
            }
            guard points.count > 1 else { continue }
            for i in 1..<points.count {
                let a = points[i - 1], b = points[i]
                ctx.setLineWidth(CGFloat((a.w + b.w) / 2) * width)
                ctx.move(to: CGPoint(x: CGFloat(a.x) * width, y: CGFloat(a.y) * width))
                ctx.addLine(to: CGPoint(x: CGFloat(b.x) * width, y: CGFloat(b.y) * width))
                ctx.strokePath()
            }
        }

        return ctx.makeImage()
    }

    // MARK: - Paper details

    /// 纸面：上亮下暖的渐变、细颗粒、四周做旧。
    static func drawPaper(_ ctx: CGContext, rect: CGRect, paper: PaperStyle) {
        let base = paper.paperRGB
        let warm = RGB(0.86, 0.80, 0.68)
        let top = paper.isDark ? base * 1.08 : ColorMath.clamp01(base * 1.012)
        let bottom = paper.isDark ? base * 0.92 : ColorMath.mix(base, warm, 0.10)
        if let space = CGColorSpace(name: CGColorSpace.sRGB),
           let gradient = CGGradient(colorsSpace: space, colors: [cgColor(top), cgColor(bottom)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        } else {
            ctx.setFillColor(cgColor(base))
            ctx.fill(rect)
        }
        // 细颗粒（确定性，和屏幕上一样细）
        var rng = SeededRandom(seed: 0x9A9E2)
        let count = Int(rect.width * rect.height / 260)
        let dot = max(1, rect.width / 900)
        for _ in 0..<count {
            let x = rect.minX + CGFloat(rng.unit()) * rect.width
            let y = rect.minY + CGFloat(rng.unit()) * rect.height
            let shade = CGFloat(rng.range(0.55, 0.85))
            let alpha = CGFloat(rng.range(0.03, 0.09)) * (paper.isDark ? 0.5 : 1)
            ctx.setFillColor(CGColor(srgbRed: shade, green: shade * 0.98, blue: shade * 0.94, alpha: alpha))
            ctx.fill(CGRect(x: x, y: y, width: dot, height: dot))
        }
        // 四周做旧
        let ageColor = paper.isDark ? CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25) : cgColor(warm * 0.9, alpha: 0.22)
        if let space = CGColorSpace(name: CGColorSpace.sRGB),
           let vignette = CGGradient(colorsSpace: space, colors: [cgColor(top, alpha: 0), ageColor] as CFArray, locations: [0, 1]) {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawRadialGradient(vignette, startCenter: center, startRadius: rect.width * 0.42, endCenter: center, endRadius: rect.height * 0.78, options: [.drawsAfterEndLocation])
        }
    }

    /// 底边药包的细微隆起：一道极淡的阴影线和一道高光线。
    static func drawPodRidge(_ ctx: CGContext, y: CGFloat, width: CGFloat, dark: Bool) {
        let line = max(1, width * 0.003)
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: dark ? 0.25 : 0.05))
        ctx.fill(CGRect(x: width * 0.05, y: y, width: width * 0.9, height: line))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: dark ? 0.05 : 0.45))
        ctx.fill(CGRect(x: width * 0.05, y: y + line, width: width * 0.9, height: line))
    }

    /// 窗口内凹：上边和左边的细影、下边的反光（在已裁到窗口的上下文里调用）。
    static func drawRecess(_ ctx: CGContext, rect: CGRect) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let depth = PrintGeometry.recessDepth(windowWidth: rect.width)
        func band(_ from: CGPoint, _ to: CGPoint, _ color: CGColor, _ clear: CGColor) {
            if let g = CGGradient(colorsSpace: space, colors: [color, clear] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: from, end: to, options: [])
            }
        }
        let clearBlack = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
        let clearWhite = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)
        band(CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY + depth), CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.26), clearBlack)
        band(CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.minX + depth, y: rect.midY), CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.16), clearBlack)
        band(CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.midX, y: rect.maxY - depth), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14), clearWhite)
    }

    // MARK: - Helpers

    static func cgColor(_ c: RGB, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: alpha)
    }

    /// 等比填满。
    public static func aspectFill(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }

    /// 在已翻转（左上原点）的上下文里正着画图。
    static func drawImage(_ ctx: CGContext, _ image: CGImage, in rect: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    /// 在已翻转的上下文里画一行居中文字。
    static func drawText(_ ctx: CGContext, _ text: String, fontName: String, size: CGFloat, color: RGB, centerX: CGFloat, baselineY: CGFloat, maxWidth: CGFloat, alpha: CGFloat = 1, tracking: CGFloat = 0) {
        var fontSize = size
        var line: CTLine
        var bounds: CGRect
        repeat {
            let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
            var attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): cgColor(color, alpha: alpha)
            ]
            if tracking != 0 {
                attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = tracking * fontSize / size
            }
            line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            bounds = CTLineGetBoundsWithOptions(line, [])
            fontSize *= 0.92
        } while bounds.width > maxWidth && fontSize > 4

        ctx.saveGState()
        ctx.translateBy(x: centerX - bounds.width / 2 - bounds.minX, y: baselineY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

/// 屏幕上的 PrintSurface 与导出的 PhotoComposer 共用的细节几何。
public enum PrintGeometry {
    /// 药包隆起线的位置（左上原点）：在厚底边靠下约三分之一处。
    public static func podRidgeY(layout: PaperLayout, width: CGFloat) -> CGFloat {
        let caption = layout.scaled(layout.captionArea, toWidth: width)
        let paperHeight = width / layout.aspect
        return caption.maxY + (paperHeight - caption.maxY) * 0.35
    }

    /// 窗口内凹阴影的深度（像素 / 点）。
    public static func recessDepth(windowWidth: CGFloat) -> CGFloat {
        max(1.5, windowWidth * 0.022)
    }
}
