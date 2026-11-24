import CoreGraphics
import CoreText
import Foundation

/// 复古印刷品的共用画法：模切白边、套色错位、油墨斑驳、网点、齿孔、扇贝边、心形……
///
/// 贴纸（`StickerArt`）和相纸模板（`TemplateArt`）都用它，保证两边是同一套「印刷质感」。
/// 所有函数都假定上下文是左上角原点、y 向下（和 `PhotoComposer` 一致）。
enum RetroPrint {
    // MARK: - 颜色

    static func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
        let c = RGB(hex: hex) ?? RGB(0.5, 0.5, 0.5)
        return CGColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: alpha)
    }

    static func color(_ c: RGB, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: alpha)
    }

    /// 两个十六进制颜色按 t 混合。
    static func mix(_ a: String, _ b: String, _ t: Float) -> CGColor {
        let ca = RGB(hex: a) ?? RGB(0.5, 0.5, 0.5)
        let cb = RGB(hex: b) ?? RGB(0.5, 0.5, 0.5)
        return color(ColorMath.mix(ca, cb, t))
    }

    // MARK: - 设计坐标

    /// 在 rect 里建立「设计坐标」：宽 100 个单位，高 100 / aspect，原点左上。
    /// body 的第二个参数是每个设计单位对应的像素数（阴影、模糊这些要按像素给的参数用它换算）。
    static func design(_ ctx: CGContext, rect: CGRect, body: (CGContext, CGFloat) -> Void) {
        guard rect.width > 0.5, rect.height > 0.5 else { return }
        let px = rect.width / 100
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: px, y: px)
        // 缩放之后，「每个设计单位对应几个设备像素」就是当前变换的缩放量。
        body(ctx, currentScale(ctx))
        ctx.restoreGState()
    }

    /// 上下文当前的缩放（用来把设计单位换算成设备像素）。
    static func currentScale(_ ctx: CGContext) -> CGFloat {
        let t = ctx.userSpaceToDeviceSpaceTransform
        return max(0.0001, sqrt(abs(t.a * t.d - t.b * t.c)))
    }

    // MARK: - 模切白边与阴影

    /// 乙烯贴纸的白色模切边：先画一圈带投影的白边，再在 `art` 里画图案（已裁到形状内）。
    /// - border：白边宽度（设计单位）。px：每个设计单位的设备像素数。
    static func vinyl(_ ctx: CGContext, shape: CGPath, border: CGFloat, px: CGFloat, art: (CGContext) -> Void) {
        // 投影 + 白边
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5 * px, height: -1.1 * px), blur: 2.4 * px, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.32))
        ctx.addPath(shape)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(border * 2)
        ctx.setStrokeColor(color("#FBF8F1"))
        ctx.setFillColor(color("#FBF8F1"))
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
        // 图案
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        art(ctx)
        ctx.restoreGState()
        // 白边的细微光泽：一道细高光
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.setLineWidth(max(0.35, border * 0.35))
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// 纸质贴纸 / 票据：柔和的投影，没有白边。
    static func paperShadow(_ ctx: CGContext, shape: CGPath, px: CGFloat, fill: CGColor) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.4 * px, height: -0.9 * px), blur: 2.0 * px, color: CGColor(srgbRed: 0.12, green: 0.08, blue: 0.04, alpha: 0.28))
        ctx.addPath(shape)
        ctx.setFillColor(fill)
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// 套色错位：先用 ghost 颜色偏一点画，再正常画。
    static func misregister(_ ctx: CGContext, ghost: CGColor, dx: CGFloat = 0.6, dy: CGFloat = 0.45, draw: (CGContext, Bool) -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: dx, y: dy)
        ctx.setAlpha(0.55)
        draw(ctx, true)
        ctx.restoreGState()
        draw(ctx, false)
        _ = ghost
    }

    // MARK: - 质感

    /// 纸纹 / 油墨颗粒：随机小点（确定性）。
    static func speckle(_ ctx: CGContext, rect: CGRect, seed: UInt64, density: CGFloat = 0.9, alpha: CGFloat = 0.08, dark: Bool = true, size: CGFloat = 0.45) {
        var rng = SeededRandom(seed: seed ^ 0x5EC1)
        let count = min(Int(rect.width * rect.height * density * 0.06), 6000)
        for _ in 0..<count {
            let x = rect.minX + CGFloat(rng.unit()) * rect.width
            let y = rect.minY + CGFloat(rng.unit()) * rect.height
            let a = CGFloat(rng.range(0.3, 1.0)) * alpha
            let s = size * CGFloat(rng.range(0.6, 1.4))
            ctx.setFillColor(dark ? CGColor(srgbRed: 0.1, green: 0.08, blue: 0.06, alpha: a) : CGColor(srgbRed: 1, green: 1, blue: 0.97, alpha: a))
            ctx.fill(CGRect(x: x, y: y, width: s, height: s))
        }
    }

    /// 橡皮章的斑驳：在已画好的油墨上「擦掉」一些小点和细纹（在透明层里调用）。
    static func distress(_ ctx: CGContext, rect: CGRect, seed: UInt64, amount: CGFloat = 1) {
        var rng = SeededRandom(seed: seed ^ 0xD15C)
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        let count = Int(rect.width * rect.height * 0.035 * amount)
        for _ in 0..<min(count, 5000) {
            let x = rect.minX + CGFloat(rng.unit()) * rect.width
            let y = rect.minY + CGFloat(rng.unit()) * rect.height
            let r = CGFloat(rng.range(0.15, 0.9))
            ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(rng.range(0.35, 1.0))))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        // 几道压印不均的浅纹
        for _ in 0..<Int(4 * amount) {
            let y = rect.minY + CGFloat(rng.unit()) * rect.height
            ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(rng.range(0.15, 0.35))))
            ctx.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: CGFloat(rng.range(0.3, 1.2))))
        }
        ctx.restoreGState()
    }

    /// 网点：在当前裁切区域里铺一层圆点（像老印刷品的阴影）。
    static func halftone(_ ctx: CGContext, rect: CGRect, spacing: CGFloat, radius: CGFloat, color: CGColor) {
        ctx.saveGState()
        ctx.setFillColor(color)
        var y = rect.minY
        var row = 0
        while y <= rect.maxY + spacing {
            var x = rect.minX + (row % 2 == 0 ? 0 : spacing / 2)
            while x <= rect.maxX + spacing {
                ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += spacing
            }
            y += spacing * 0.866
            row += 1
        }
        ctx.restoreGState()
    }

    // MARK: - 形状

    /// 多角星。
    static func star(center: CGPoint, points: Int, outer: CGFloat, inner: CGFloat, rotation: CGFloat = -.pi / 2) -> CGPath {
        let path = CGMutablePath()
        let n = max(points, 2) * 2
        for i in 0..<n {
            let r = i % 2 == 0 ? outer : inner
            let a = rotation + CGFloat(i) * .pi / CGFloat(max(points, 2))
            let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// 心形（填满 rect，尖朝下）。
    static func heart(in rect: CGRect) -> CGPath {
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.98))
        path.addCurve(to: CGPoint(x: x + w * 0.02, y: y + h * 0.36), control1: CGPoint(x: x + w * 0.32, y: y + h * 0.80), control2: CGPoint(x: x + w * 0.02, y: y + h * 0.62))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.16), control1: CGPoint(x: x + w * 0.02, y: y + h * 0.06), control2: CGPoint(x: x + w * 0.40, y: y - h * 0.02))
        path.addCurve(to: CGPoint(x: x + w * 0.98, y: y + h * 0.36), control1: CGPoint(x: x + w * 0.60, y: y - h * 0.02), control2: CGPoint(x: x + w * 0.98, y: y + h * 0.06))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.98), control1: CGPoint(x: x + w * 0.98, y: y + h * 0.62), control2: CGPoint(x: x + w * 0.68, y: y + h * 0.80))
        path.closeSubpath()
        return path
    }

    /// 扇贝边（老照片的毛边 / 蕾丝）：沿矩形四边排一圈半圆。
    static func scallopedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = max(radius, 0.5)
        func count(_ length: CGFloat) -> Int { max(2, Int((length / (r * 2)).rounded())) }
        let nx = count(rect.width)
        let ny = count(rect.height)
        let sx = rect.width / CGFloat(nx)
        let sy = rect.height / CGFloat(ny)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        for i in 0..<nx {
            let x0 = rect.minX + CGFloat(i) * sx
            path.addQuadCurve(to: CGPoint(x: x0 + sx, y: rect.minY), control: CGPoint(x: x0 + sx / 2, y: rect.minY - r))
        }
        for i in 0..<ny {
            let y0 = rect.minY + CGFloat(i) * sy
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: y0 + sy), control: CGPoint(x: rect.maxX + r, y: y0 + sy / 2))
        }
        for i in 0..<nx {
            let x0 = rect.maxX - CGFloat(i) * sx
            path.addQuadCurve(to: CGPoint(x: x0 - sx, y: rect.maxY), control: CGPoint(x: x0 - sx / 2, y: rect.maxY + r))
        }
        for i in 0..<ny {
            let y0 = rect.maxY - CGFloat(i) * sy
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: y0 - sy), control: CGPoint(x: rect.minX - r, y: y0 - sy / 2))
        }
        path.closeSubpath()
        return path
    }

    /// 邮票齿孔：矩形减去沿四边排开的小圆孔（圆心在边上，咬出一个个半圆缺口）。
    static func perforated(_ rect: CGRect, hole: CGFloat, spacing: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let step = max(spacing, hole * 2.2)
        func holes(from a: CGPoint, to b: CGPoint) {
            let length = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int(length / step))
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                path.addEllipse(in: CGRect(x: c.x - hole, y: c.y - hole, width: hole * 2, height: hole * 2))
            }
        }
        holes(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.minY))
        holes(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.maxX, y: rect.maxY))
        holes(from: CGPoint(x: rect.minX, y: rect.minY + step), to: CGPoint(x: rect.minX, y: rect.maxY - step))
        holes(from: CGPoint(x: rect.maxX, y: rect.minY + step), to: CGPoint(x: rect.maxX, y: rect.maxY - step))
        return CGPath(rect: rect, transform: nil).subtracting(path)
    }

    /// 撕口：一条锯齿边（胶带两端），沿竖直方向。
    static func tornEdge(_ path: CGMutablePath, x: CGFloat, top: CGFloat, bottom: CGFloat, depth: CGFloat, seed: UInt64, reverse: Bool) {
        var rng = SeededRandom(seed: seed)
        let steps = max(4, Int((bottom - top) / 1.6))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let y = reverse ? bottom - (bottom - top) * t : top + (bottom - top) * t
            let dx = CGFloat(rng.unit()) * depth
            path.addLine(to: CGPoint(x: reverse ? x - dx : x + dx, y: y))
        }
    }

    // MARK: - 文字

    /// 按候选名字找第一个装了的字体（CoreText 找不到时会给 Helvetica，用 PostScript 名判断）。
    static func font(_ names: [String], size: CGFloat) -> CTFont {
        for name in names {
            let font = CTFontCreateWithName(name as CFString, size, nil)
            let actual = CTFontCopyPostScriptName(font) as String
            let family = CTFontCopyFamilyName(font) as String
            if actual == name || family == name || actual.hasPrefix(name) {
                return font
            }
        }
        return CTFontCreateWithName((names.last ?? "Helvetica-Bold") as CFString, size, nil)
    }

    static let condensed = ["Futura-CondensedExtraBold", "AvenirNextCondensed-Heavy", "Helvetica-Bold"]
    static let serifBold = ["Didot-Bold", "Baskerville-Bold", "Times-Bold"]
    static let typewriter = ["AmericanTypewriter-Semibold", "AmericanTypewriter", "Courier-Bold"]
    static let chineseSerif = ["STSongti-SC-Bold", "Songti SC", "STSong"]

    /// 一行文字的宽度。
    static func width(_ text: String, font: CTFont, tracking: CGFloat = 0) -> CGFloat {
        CTLineGetBoundsWithOptions(line(text, font: font, color: color("#000000"), tracking: tracking), []).width
    }

    static func line(_ text: String, font: CTFont, color: CGColor, tracking: CGFloat = 0) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        if tracking != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = tracking
        }
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// 在 y 向下的上下文里画一行字：x 是中心（align = 0）、左边（-1）或右边（1），y 是基线。
    /// maxWidth 超出时自动缩小字号。
    @discardableResult
    static func text(_ ctx: CGContext, _ text: String, fonts: [String], size: CGFloat, color: CGColor, x: CGFloat, baseline: CGFloat, align: Int = 0, maxWidth: CGFloat = .greatestFiniteMagnitude, tracking: CGFloat = 0) -> CGRect {
        guard !text.isEmpty else { return .zero }
        var fontSize = size
        var font = RetroPrint.font(fonts, size: fontSize)
        var built = line(text, font: font, color: color, tracking: tracking * fontSize / max(size, 0.001))
        var bounds = CTLineGetBoundsWithOptions(built, [])
        while bounds.width > maxWidth, fontSize > 2 {
            fontSize *= 0.92
            font = RetroPrint.font(fonts, size: fontSize)
            built = line(text, font: font, color: color, tracking: tracking * fontSize / max(size, 0.001))
            bounds = CTLineGetBoundsWithOptions(built, [])
        }
        let left: CGFloat
        switch align {
        case ..<0: left = x
        case 1...: left = x - bounds.width
        default: left = x - bounds.width / 2
        }
        ctx.saveGState()
        ctx.translateBy(x: left - bounds.minX, y: baseline)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(built, ctx)
        ctx.restoreGState()
        return CGRect(x: left, y: baseline - bounds.maxY, width: bounds.width, height: bounds.height)
    }

    /// 沿圆弧排字（邮戳）：startAngle 是第一个字的角度（弧度，0 = 右边，y 向下时顺时针）。
    static func arcText(_ ctx: CGContext, _ text: String, fonts: [String], size: CGFloat, color: CGColor, center: CGPoint, radius: CGFloat, startAngle: CGFloat, spacing: CGFloat) {
        let font = RetroPrint.font(fonts, size: size)
        var angle = startAngle
        for character in text {
            let built = line(String(character), font: font, color: color)
            let bounds = CTLineGetBoundsWithOptions(built, [])
            ctx.saveGState()
            ctx.translateBy(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            ctx.rotate(by: angle + .pi / 2)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: -bounds.width / 2 - bounds.minX, y: 0)
            CTLineDraw(built, ctx)
            ctx.restoreGState()
            angle += (bounds.width + spacing) / max(radius, 0.001)
        }
    }

    /// 一段文字沿圆弧占的角度（排邮戳文字时用来居中）。
    static func arcSpan(_ text: String, fonts: [String], size: CGFloat, radius: CGFloat, spacing: CGFloat) -> CGFloat {
        let font = RetroPrint.font(fonts, size: size)
        var total: CGFloat = 0
        for character in text {
            total += CTLineGetBoundsWithOptions(line(String(character), font: font, color: color("#000000")), []).width + spacing
        }
        return (total - spacing) / max(radius, 0.001)
    }
}
