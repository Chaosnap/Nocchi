import CoreGraphics
import CoreText
import Foundation
import NocchiKit

/// 卡片盒场景用到的程序化贴图：木纹、点阵桌面、环境光、字母标签。
enum ProceduralTextures {
    static func context(_ width: Int, _ height: Int) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    static func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
        let c = RGB(hex: hex) ?? RGB(0.5, 0.5, 0.5)
        return CGColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: alpha)
    }

    /// 木纹：底色 + 宽色带 + 正弦纹理线 + 节疤。
    static func wood(width: Int = 1024, height: Int = 512, base: String = "#B97A40", dark: String = "#6E401C", seed: UInt64 = 5) -> CGImage? {
        guard let ctx = context(width, height) else { return nil }
        let w = Double(width), h = Double(height)
        ctx.setFillColor(color(base))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        var rng = SeededRandom(seed: seed)

        for _ in 0..<16 {
            let y = rng.range(0, h)
            let band = rng.range(8, 54)
            ctx.setFillColor(color(dark, CGFloat(rng.range(0.03, 0.11))))
            ctx.fill(CGRect(x: 0, y: y, width: w, height: band))
        }

        ctx.setLineCap(.round)
        for _ in 0..<240 {
            let y0 = rng.range(0, h)
            let amplitude = rng.range(1.5, 9)
            let frequency = rng.range(0.002, 0.009)
            let phase = rng.range(0, 6.283)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y0 + sin(phase) * amplitude))
            var x = 0.0
            while x <= w {
                x += 8
                let y = y0 + sin(x * frequency + phase) * amplitude + sin(x * frequency * 3.3 + phase * 2) * amplitude * 0.3
                path.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.addPath(path)
            ctx.setStrokeColor(color(dark, CGFloat(rng.range(0.05, 0.26))))
            ctx.setLineWidth(CGFloat(rng.range(0.6, 2.8)))
            ctx.strokePath()
        }

        for _ in 0..<2 {
            let cx = rng.range(90, w - 90)
            let cy = rng.range(40, h - 40)
            var r = 28.0
            while r > 3 {
                ctx.setStrokeColor(color(dark, 0.2))
                ctx.setLineWidth(1.3)
                ctx.strokeEllipse(in: CGRect(x: cx - r * 1.9, y: cy - r, width: r * 3.8, height: r * 2))
                r -= 4
            }
        }
        return ctx.makeImage()
    }

    /// 浅色点阵桌面（平铺用的一格）。
    static func dots(size: Int = 128, background: String = "#E8E4DC", dot: String = "#CEC9BF") -> CGImage? {
        guard let ctx = context(size, size) else { return nil }
        let s = CGFloat(size)
        ctx.setFillColor(color(background))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
        ctx.setFillColor(color(dot))
        let r = s * 0.04
        ctx.fillEllipse(in: CGRect(x: s / 2 - r, y: s / 2 - r, width: r * 2, height: r * 2))
        return ctx.makeImage()
    }

    /// 环境光：上亮下暗，带一块柔和的「窗户」高光，给光面相纸和金属反光。
    static func environment() -> CGImage? {
        let width = 512, height = 256
        guard let ctx = context(width, height),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let colors = [color("#FFFFFF"), color("#F4ECDF"), color("#8E857A"), color("#3A342E")] as CFArray
        let locations: [CGFloat] = [0, 0.35, 0.7, 1]
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
        }
        ctx.setFillColor(color("#FFFFFF", 0.95))
        ctx.fill(CGRect(x: 150, y: 176, width: 96, height: 46))
        ctx.setFillColor(color("#FFF3E0", 0.7))
        ctx.fill(CGRect(x: 330, y: 186, width: 60, height: 30))
        return ctx.makeImage()
    }

    /// 索引卡标签上的字母。
    static func label(_ text: String, width: Int = 128, height: Int = 96, background: String = "#EFE4CC") -> CGImage? {
        guard let ctx = context(width, height) else { return nil }
        ctx.setFillColor(color(background))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Georgia-Bold" as CFString, CGFloat(height) * 0.6, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color("#2A231C")
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(
            x: (CGFloat(width) - bounds.width) / 2 - bounds.minX,
            y: (CGFloat(height) - bounds.height) / 2 - bounds.minY
        )
        CTLineDraw(line, ctx)
        return ctx.makeImage()
    }
}
