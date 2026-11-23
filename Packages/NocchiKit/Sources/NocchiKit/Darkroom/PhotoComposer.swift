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
    /// 题字字体（马克笔风格，系统自带；中文字形由系统自动回落）。
    public static let captionFontName = "MarkerFelt-Wide"
    public static let dateFontName = "MarkerFelt-Thin"

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

        // 相纸
        let corner = layout.cornerRadius * s
        ctx.addPath(CGPath(roundedRect: paperRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.setFillColor(cgColor(paperColor))
        ctx.fillPath()

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
            ctx.restoreGState()
            // 窗口边缘一圈很淡的压痕
            ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: spec.paper.isDark ? 0.35 : 0.10))
            ctx.setLineWidth(max(1, s * 0.22))
            ctx.stroke(rect)
        }

        // 题字与日期
        let caption = layout.scaled(layout.captionArea, toWidth: width)
        let ink = spec.paper.inkRGB
        if let text = spec.caption, !text.isEmpty {
            let size = captionFontSize(paperWidth: width, layout: layout)
            let baselineY = spec.dateText == nil ? caption.midY + size * 0.35 : caption.minY + caption.height * 0.5
            drawText(ctx, text, fontName: captionFontName, size: size, color: ink, centerX: caption.midX, baselineY: baselineY, maxWidth: caption.width)
        }
        if let date = spec.dateText {
            let size = dateFontSize(paperWidth: width, layout: layout)
            let baselineY = (spec.caption?.isEmpty == false) ? caption.minY + caption.height * 0.86 : caption.midY + size * 0.35
            drawText(ctx, date, fontName: dateFontName, size: size, color: ink, centerX: caption.midX, baselineY: baselineY, maxWidth: caption.width, alpha: 0.75)
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
    static func drawText(_ ctx: CGContext, _ text: String, fontName: String, size: CGFloat, color: RGB, centerX: CGFloat, baselineY: CGFloat, maxWidth: CGFloat, alpha: CGFloat = 1) {
        var fontSize = size
        var line: CTLine
        var bounds: CGRect
        repeat {
            let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): cgColor(color, alpha: alpha)
            ]
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
