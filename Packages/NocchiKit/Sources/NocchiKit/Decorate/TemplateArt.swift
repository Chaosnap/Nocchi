import CoreGraphics
import CoreText
import Foundation

/// 相纸模板的画法（Core Graphics）。像素坐标，原点左上、y 向下。
///
/// - `outline`：相纸外轮廓（毛边、邮票齿孔不是矩形）。
/// - `drawBase`：照片下面的纸面与底纹（调用方已经裁到外轮廓）。
/// - `drawForeground`：照片上面、题字下面的图样（照片角、日期机数字、横幅、星星……）。
enum TemplateArt {
    /// 每毫米多少像素。
    static func scale(_ layout: PaperLayout, width: CGFloat) -> CGFloat {
        width / layout.paperSize.width
    }

    static func c(_ hex: String, _ alpha: CGFloat = 1) -> CGColor { RetroPrint.color(hex, alpha) }

    // MARK: - 外轮廓

    /// 相纸外轮廓；`evenOdd` 为 true 时要用 even-odd 规则填充 / 裁切。
    static func outline(_ template: PrintTemplate, layout: PaperLayout, size: CGSize) -> (path: CGPath, evenOdd: Bool) {
        let s = scale(layout, width: size.width)
        let rect = CGRect(origin: .zero, size: size)
        switch template.style {
        case .deckle:
            let r = 1.15 * s
            return (RetroPrint.scallopedRect(rect.insetBy(dx: r + 0.4 * s, dy: r + 0.4 * s), radius: r), false)
        case .postage:
            let hole = 1.05 * s
            return (CGPath(rect: rect.insetBy(dx: hole * 0.2, dy: hole * 0.2), transform: nil), false)
        default:
            let corner = layout.cornerRadius * s
            return (CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil), false)
        }
    }

    // MARK: - 窗口

    /// 第 index 个窗口的形状（像素）。
    static func window(_ template: PrintTemplate, layout: PaperLayout, index: Int, width: CGFloat) -> CGPath {
        guard index >= 0, index < layout.windows.count else { return CGMutablePath() }
        let rect = layout.scaled(layout.windows[index], toWidth: width)
        switch template.windowShape {
        case .rect:
            return CGPath(rect: rect, transform: nil)
        case .heart:
            return RetroPrint.heart(in: rect.insetBy(dx: rect.width * 0.03, dy: rect.height * 0.05))
        }
    }

    // MARK: - 题字区域与默认题字

    /// 题字实际可用的区域（有些模板在底边画了东西，要让开）。
    static func captionArea(_ spec: PrintSpec, width: CGFloat) -> CGRect {
        let layout = spec.layout
        let s = scale(layout, width: width)
        var area = layout.scaled(layout.captionArea, toWidth: width)
        switch spec.template.style {
        case .seventies:
            let cut = min(5.6 * s, area.height * 0.45)
            area.size.height -= cut
        case .filmframe where layout.windows.count == 1 && area.height > 10 * s:
            area.size.height -= 3.2 * s
        case .cabinet:
            area.size.height -= min(3.4 * s, area.height * 0.25)
        default:
            break
        }
        return area
    }

    /// 没写题字时模板自带的字。
    static func defaultCaption(_ template: PrintTemplate) -> String? {
        switch template.style {
        case .boothBirthday: return String(localized: "生日快乐")
        case .boothNewYear: return String(localized: "新年快乐")
        default: return nil
        }
    }

    // MARK: - 照片下面

    static func drawBase(_ ctx: CGContext, spec: PrintSpec, size: CGSize) {
        let layout = spec.layout
        let s = scale(layout, width: size.width)
        let rect = CGRect(origin: .zero, size: size)
        let paper = spec.paper
        switch spec.template.style {
        case .kraft:
            drawKraft(ctx, rect: rect, s: s, seed: spec.seed)
        case .filmframe:
            ctx.setFillColor(c("#17110D"))
            ctx.fill(rect)
            RetroPrint.speckle(ctx, rect: rect, seed: spec.seed, density: 0.002 / max(s * s, 0.0001) * 900, alpha: 0.05, dark: false, size: max(1, s * 0.1))
        case .album:
            ctx.setFillColor(c("#1B1A18"))
            ctx.fill(rect)
            RetroPrint.speckle(ctx, rect: rect, seed: spec.seed, density: 0.002 / max(s * s, 0.0001) * 900, alpha: 0.06, dark: false, size: max(1, s * 0.1))
        case .cabinet:
            drawCabinet(ctx, rect: rect, s: s, seed: spec.seed)
        case .boothNewYear:
            PhotoComposer.drawPaper(ctx, rect: rect, paper: paper)
            drawMeander(ctx, rect: rect, s: s)
        case .boothStars:
            PhotoComposer.drawPaper(ctx, rect: rect, paper: paper)
        case .boothHeart:
            // Blender 渲染的卡纸 + 模切纸蕾丝边（FrameLayers）；没有图时退回程序化画法。
            if let layer = FrameLayers.valentine(.base, layout: layout, size: size) {
                PhotoComposer.drawImage(ctx, layer, in: rect)
            } else {
                PhotoComposer.drawPaper(ctx, rect: rect, paper: paper)
                drawLace(ctx, rect: rect, s: s)
            }
        case .boothBirthday:
            PhotoComposer.drawPaper(ctx, rect: rect, paper: paper)
            drawBunting(ctx, spec: spec, rect: rect, s: s)
        default:
            PhotoComposer.drawPaper(ctx, rect: rect, paper: paper)
        }

        // 即显相纸的药包隆起（只给保留相纸本色的模板）。
        let instantLike = layout.windows.count == 1 && layout.captionArea.height > layout.paperSize.height * 0.12
        if instantLike, [.classic, .noir, .kraft, .datebook, .seventies].contains(spec.template.style) {
            PhotoComposer.drawPodRidge(ctx, y: PrintGeometry.podRidgeY(layout: layout, width: size.width), width: size.width, dark: paper.isDark)
        }

        switch spec.template.style {
        case .noir:
            ctx.setStrokeColor(c("#EDE6D8", 0.16))
            ctx.setLineWidth(max(1, 0.2 * s))
            let inset = 1.6 * s
            ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: inset, dy: inset), cornerWidth: inset * 0.6, cornerHeight: inset * 0.6, transform: nil))
            ctx.strokePath()
        case .deckle:
            for window in layout.windows {
                let frame = layout.scaled(window, toWidth: size.width).insetBy(dx: -1.6 * s, dy: -1.6 * s)
                ctx.setLineWidth(max(1, 0.25 * s))
                ctx.setStrokeColor(c("#FFFFFF", 0.7))
                ctx.stroke(frame.offsetBy(dx: 0.2 * s, dy: 0.2 * s))
                ctx.setStrokeColor(c("#5A4632", 0.22))
                ctx.stroke(frame)
            }
        case .postage:
            let inset = 2.2 * s
            ctx.setStrokeColor(c("#2F4C8A", 0.75))
            ctx.setLineWidth(max(1, 0.3 * s))
            ctx.stroke(rect.insetBy(dx: inset, dy: inset))
            let top = layout.scaled(layout.windows[0], toWidth: size.width).minY
            let textSize = min(top * 0.42, 2.4 * s)
            RetroPrint.text(ctx, "NOCCHI POST", fonts: RetroPrint.typewriter, size: textSize, color: c("#2F4C8A"), x: inset + 1.2 * s, baseline: top - 0.9 * s, align: -1, tracking: 0.3 * s)
            RetroPrint.text(ctx, "8分", fonts: RetroPrint.chineseSerif, size: textSize * 1.2, color: c("#B23A2A"), x: size.width - inset - 1.2 * s, baseline: top - 0.9 * s, align: 1) // i18n-ok：邮票面值（图案）
        case .seventies:
            let colors = ["#D9A441", "#C4593B", "#5A3A28"]
            let band = 1.5 * s
            let bottom = size.height - 1.6 * s
            for (i, hex) in colors.enumerated() {
                let y = bottom - band * CGFloat(3 - i)
                ctx.setFillColor(c(hex))
                ctx.fill(CGRect(x: 0, y: y, width: size.width, height: band * 0.82))
            }
        case .cabinet:
            for window in layout.windows {
                let frame = layout.scaled(window, toWidth: size.width)
                foilStroke(ctx, frame.insetBy(dx: -1.3 * s, dy: -1.3 * s), width: max(1, 0.35 * s))
                foilStroke(ctx, frame.insetBy(dx: -2.1 * s, dy: -2.1 * s), width: max(1, 0.15 * s))
            }
        default:
            break
        }

        // 窗口里先铺一层暗色（照片有错位时露出来的是暗边，和以前一样）。
        for index in layout.windows.indices {
            ctx.addPath(window(spec.template, layout: layout, index: index, width: size.width))
        }
        ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1))
        ctx.fillPath()

        // 胶片框的齿孔：真的挖空（透出下面的东西）。
        if spec.template.style == .filmframe {
            punchSprockets(ctx, layout: layout, size: size, s: s)
        }
        // 邮票的齿孔边：沿边挖出半圆缺口（底层是独立的位图，挖掉的地方就是透明）。
        if spec.template.style == .postage {
            let hole = 1.05 * s
            RetroPrint.punch(ctx, RetroPrint.perforations(rect.insetBy(dx: hole * 0.2, dy: hole * 0.2), hole: hole, spacing: 3.1 * s))
        }
    }

    // MARK: - 照片上面

    static func drawForeground(_ ctx: CGContext, spec: PrintSpec, size: CGSize) {
        let layout = spec.layout
        let s = scale(layout, width: size.width)
        switch spec.template.style {
        case .datebook:
            if let date = spec.dateText, let first = layout.windows.first {
                let window = layout.scaled(first, toWidth: size.width)
                drawDateDigits(ctx, text: dateBackText(date), window: window)
            }
        case .album:
            for window in layout.windows {
                photoCorners(ctx, layout.scaled(window, toWidth: size.width), s: s)
            }
        case .postage:
            if let first = layout.windows.first {
                let window = layout.scaled(first, toWidth: size.width)
                postmark(ctx, center: CGPoint(x: window.maxX - window.width * 0.08, y: window.minY + window.height * 0.08), radius: window.width * 0.16, seed: spec.seed, date: spec.dateText)
            }
        case .filmframe:
            let edge = "NOCCHI ▸ \(Int(spec.seed % 36) + 1)A"
            if layout.windows.count == 1, let first = layout.windows.first {
                let window = layout.scaled(first, toWidth: size.width)
                RetroPrint.text(ctx, edge, fonts: RetroPrint.typewriter, size: 1.6 * s, color: c("#E39B3A", 0.9), x: window.minX, baseline: window.maxY + 2.1 * s, align: -1, tracking: 0.25 * s)
            }
        case .boothNoir, .boothStars, .noir, .cabinet:
            break
        case .boothHeart:
            // Blender 渲染的纸蕾丝心环、烫金线、缎带蝴蝶结、金色小心与花线（带阴影）；没有图时退回程序化画法。
            if let layer = FrameLayers.valentine(.overlay, layout: layout, size: size) {
                PhotoComposer.drawImage(ctx, layer, in: CGRect(origin: .zero, size: size))
                break
            }
            for index in layout.windows.indices {
                ctx.addPath(window(spec.template, layout: layout, index: index, width: size.width))
            }
            ctx.setStrokeColor(c("#FFFFFF", 0.85))
            ctx.setLineWidth(max(1, 0.45 * s))
            ctx.strokePath()
            scatterHearts(ctx, layout: layout, size: size, s: s, seed: spec.seed)
        case .boothBirthday:
            for (index, window) in layout.windows.enumerated() {
                banner(ctx, window: layout.scaled(window, toWidth: size.width), s: s, colorHex: ["#C4593B", "#2F5F5C", "#D9A441", "#2F4C8A"][index % 4])
            }
        case .boothClassic:
            let area = layout.scaled(layout.captionArea, toWidth: size.width)
            var rng = SeededRandom(seed: spec.seed ^ 0xB007)
            let serial = String(format: "No. %04d", Int(rng.range(1, 9999)))
            RetroPrint.text(ctx, serial, fonts: RetroPrint.typewriter, size: min(area.height * 0.26, 2.4 * s), color: c("#2E2924", 0.55), x: area.minX, baseline: area.maxY - 0.4 * s, align: -1, tracking: 0.2 * s)
        default:
            break
        }
        if spec.template.style == .boothStars {
            scatterStars(ctx, layout: layout, size: size, s: s, seed: spec.seed)
        }
    }

    // MARK: - 纸张

    private static func drawKraft(_ ctx: CGContext, rect: CGRect, s: CGFloat, seed: UInt64) {
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#C2A27C"), c("#B18F68")] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        var rng = SeededRandom(seed: seed ^ 0xC4AF)
        let count = min(Int(rect.width * rect.height / max(s * s, 0.01) * 0.25), 4000)
        ctx.setLineCap(.round)
        for _ in 0..<count {
            let x = rect.minX + CGFloat(rng.unit()) * rect.width
            let y = rect.minY + CGFloat(rng.unit()) * rect.height
            let length = CGFloat(rng.range(0.4, 1.6)) * s
            let angle = CGFloat(rng.range(-0.5, 0.5))
            let dark = rng.unit() < 0.6
            ctx.setStrokeColor(dark ? c("#5A3A20", CGFloat(rng.range(0.05, 0.16))) : c("#F2E0C0", CGFloat(rng.range(0.08, 0.2))))
            ctx.setLineWidth(max(0.5, CGFloat(rng.range(0.04, 0.1)) * s))
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
            ctx.strokePath()
        }
        RetroPrint.speckle(ctx, rect: rect, seed: seed, density: 0.003 / max(s * s, 0.0001) * 900, alpha: 0.12, dark: true, size: max(1, s * 0.12))
    }

    private static func drawCabinet(_ ctx: CGContext, rect: CGRect, s: CGFloat, seed: UInt64) {
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#46332A"), c("#33241C")] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        RetroPrint.speckle(ctx, rect: rect, seed: seed, density: 0.003 / max(s * s, 0.0001) * 900, alpha: 0.08, dark: false, size: max(1, s * 0.1))
        let bottom = rect.maxY - 1.9 * s
        foilText(ctx, "✦ NOCCHI STUDIO ✦", size: 1.9 * s, x: rect.midX, baseline: bottom, tracking: 0.5 * s)
    }

    /// 烫金描边。
    static func foilStroke(_ ctx: CGContext, _ rect: CGRect, width: CGFloat) {
        ctx.saveGState()
        ctx.setLineWidth(width)
        ctx.addRect(rect)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#F3DEA4"), c("#B8955A"), c("#7A5A2E"), c("#E3C98F")] as CFArray, locations: [0, 0.35, 0.7, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        }
        ctx.restoreGState()
    }

    /// 烫金字。
    static func foilText(_ ctx: CGContext, _ text: String, size: CGFloat, x: CGFloat, baseline: CGFloat, tracking: CGFloat = 0) {
        RetroPrint.text(ctx, text, fonts: RetroPrint.serifBold, size: size, color: c("#5A4020", 0.6), x: x + size * 0.04, baseline: baseline + size * 0.04, tracking: tracking)
        RetroPrint.text(ctx, text, fonts: RetroPrint.serifBold, size: size, color: c("#E3C98F"), x: x, baseline: baseline, tracking: tracking)
    }

    // MARK: - 图样

    /// 日期机的橙色七段数字（照片右下角，发光）。
    private static func drawDateDigits(_ ctx: CGContext, text: String, window: CGRect) {
        let digitHeight = window.height * 0.07
        let digitWidth = digitHeight * 0.55
        let gap = digitWidth * 0.45
        let stroke = digitHeight * 0.13
        var widths: CGFloat = 0
        for ch in text {
            widths += ch == " " ? gap * 1.6 : (ch == "'" ? stroke * 2 : digitWidth + gap)
        }
        var x = window.maxX - window.width * 0.06 - widths
        let top = window.maxY - window.height * 0.06 - digitHeight
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: digitHeight * 0.5, color: c("#FF6A1A", 0.85))
        ctx.setFillColor(c("#FF9A3C", 0.95))
        for ch in text {
            if ch == " " {
                x += gap * 1.6
                continue
            }
            if ch == "'" {
                ctx.fill(CGRect(x: x, y: top, width: stroke, height: stroke * 2.2))
                x += stroke * 2
                continue
            }
            for segment in segments(for: ch) {
                ctx.addPath(sevenSegment(segment, x: x, y: top, w: digitWidth, h: digitHeight, t: stroke))
            }
            ctx.fillPath()
            x += digitWidth + gap
        }
        ctx.restoreGState()
    }

    /// 「2026/11/23」→「'26 11 23」。
    static func dateBackText(_ date: String) -> String {
        let parts = date.split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard parts.count >= 3 else { return date }
        let year = String(parts[0].suffix(2))
        return "'\(year) \(parts[1]) \(parts[2])"
    }

    /// 七段：a 上、b 右上、c 右下、d 下、e 左下、f 左上、g 中。
    private static func segments(for ch: Character) -> [Character] {
        switch ch {
        case "0": return ["a", "b", "c", "d", "e", "f"]
        case "1": return ["b", "c"]
        case "2": return ["a", "b", "g", "e", "d"]
        case "3": return ["a", "b", "g", "c", "d"]
        case "4": return ["f", "g", "b", "c"]
        case "5": return ["a", "f", "g", "c", "d"]
        case "6": return ["a", "f", "g", "e", "c", "d"]
        case "7": return ["a", "b", "c"]
        case "8": return ["a", "b", "c", "d", "e", "f", "g"]
        case "9": return ["a", "b", "c", "d", "f", "g"]
        default: return ["g"]
        }
    }

    private static func sevenSegment(_ segment: Character, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, t: CGFloat) -> CGPath {
        let half = h / 2
        let rect: CGRect
        switch segment {
        case "a": rect = CGRect(x: x + t * 0.6, y: y, width: w - t * 1.2, height: t)
        case "b": rect = CGRect(x: x + w - t, y: y + t * 0.6, width: t, height: half - t * 0.9)
        case "c": rect = CGRect(x: x + w - t, y: y + half + t * 0.3, width: t, height: half - t * 0.9)
        case "d": rect = CGRect(x: x + t * 0.6, y: y + h - t, width: w - t * 1.2, height: t)
        case "e": rect = CGRect(x: x, y: y + half + t * 0.3, width: t, height: half - t * 0.9)
        case "f": rect = CGRect(x: x, y: y + t * 0.6, width: t, height: half - t * 0.9)
        default: rect = CGRect(x: x + t * 0.6, y: y + half - t / 2, width: w - t * 1.2, height: t)
        }
        return CGPath(roundedRect: rect, cornerWidth: t * 0.4, cornerHeight: t * 0.4, transform: nil)
    }

    /// 老相册的四个照片角。
    private static func photoCorners(_ ctx: CGContext, _ window: CGRect, s: CGFloat) {
        let size = min(window.width, window.height) * 0.16
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: window.minX, y: window.minY), 1, 1),
            (CGPoint(x: window.maxX, y: window.minY), -1, 1),
            (CGPoint(x: window.minX, y: window.maxY), 1, -1),
            (CGPoint(x: window.maxX, y: window.maxY), -1, -1)
        ]
        for (origin, sx, sy) in corners {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: origin.x - sx * size * 0.12, y: origin.y - sy * size * 0.12))
            path.addLine(to: CGPoint(x: origin.x + sx * size, y: origin.y - sy * size * 0.12))
            path.addLine(to: CGPoint(x: origin.x - sx * size * 0.12, y: origin.y + sy * size))
            path.closeSubpath()
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -0.25 * s), blur: 0.6 * s, color: c("#000000", 0.45))
            ctx.addPath(path)
            ctx.setFillColor(c("#0E0D0C"))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.setStrokeColor(c("#FFFFFF", 0.14))
            ctx.setLineWidth(max(0.5, 0.12 * s))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    /// 邮戳（半透明灰墨，压在照片一角）。
    private static func postmark(_ ctx: CGContext, center: CGPoint, radius: CGFloat, seed: UInt64, date: String?) {
        let ink = c("#2E2E36", 0.62)
        let bounds = CGRect(x: center.x - radius * 2.4, y: center.y - radius * 1.2, width: radius * 3.6, height: radius * 2.4)
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(max(1, radius * 0.06))
        ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.strokePath()
        ctx.setLineWidth(max(0.5, radius * 0.03))
        ctx.addEllipse(in: CGRect(x: center.x - radius * 0.8, y: center.y - radius * 0.8, width: radius * 1.6, height: radius * 1.6))
        ctx.strokePath()
        RetroPrint.text(ctx, date ?? "NOCCHI", fonts: RetroPrint.typewriter, size: radius * 0.26, color: ink, x: center.x, baseline: center.y + radius * 0.09, maxWidth: radius * 1.5)
        ctx.setLineWidth(max(1, radius * 0.05))
        for i in 0..<4 {
            let y = center.y - radius * 0.6 + CGFloat(i) * radius * 0.4
            ctx.move(to: CGPoint(x: center.x - radius * 2.3, y: y))
            var x = center.x - radius * 2.3
            var up = true
            while x < center.x - radius * 1.1 {
                ctx.addQuadCurve(to: CGPoint(x: x + radius * 0.3, y: y), control: CGPoint(x: x + radius * 0.15, y: y + (up ? -1 : 1) * radius * 0.12))
                x += radius * 0.3
                up.toggle()
            }
        }
        ctx.strokePath()
        RetroPrint.distress(ctx, rect: bounds, seed: seed, amount: 0.002 * bounds.width * bounds.height / max(radius * radius * 0.01, 0.0001))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    /// 胶片框的齿孔：沿相纸边挖空。
    private static func punchSprockets(_ ctx: CGContext, layout: PaperLayout, size: CGSize, s: CGFloat) {
        let pitch = 4.75 * s
        let holeW = 1.9 * s
        let holeH = 2.6 * s
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        let vertical = size.height > size.width * 1.3
        if vertical {
            let windowsMinX = layout.windows.map { $0.minX }.min() ?? 4
            let margin = windowsMinX * s
            var y = pitch * 0.5
            while y < size.height - holeW {
                for x in [margin / 2, size.width - margin / 2] {
                    ctx.addPath(CGPath(roundedRect: CGRect(x: x - holeW / 2 * 0.8, y: y, width: holeW * 0.8, height: holeH * 0.75), cornerWidth: 0.35 * s, cornerHeight: 0.35 * s, transform: nil))
                }
                y += pitch
            }
        } else {
            let top = (layout.windows.first?.minY ?? 4) * s
            var x = pitch * 0.5
            while x < size.width - holeW {
                ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: top / 2 - holeH / 2 * 0.7, width: holeW, height: holeH * 0.7), cornerWidth: 0.35 * s, cornerHeight: 0.35 * s, transform: nil))
                ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: size.height - 1.6 * s - holeH * 0.7, width: holeW, height: holeH * 0.7), cornerWidth: 0.35 * s, cornerHeight: 0.35 * s, transform: nil))
                x += pitch
            }
        }
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// 情人节模板的蕾丝花边：沿相纸边一圈白色扇贝 + 小孔。
    private static func drawLace(_ ctx: CGContext, rect: CGRect, s: CGFloat) {
        let band = 2.4 * s
        let inner = rect.insetBy(dx: band, dy: band)
        let lace = CGMutablePath()
        lace.addRect(rect)
        lace.addPath(RetroPrint.scallopedRect(inner, radius: 0.9 * s))
        ctx.saveGState()
        ctx.addPath(lace)
        ctx.setFillColor(c("#FFFDF9", 0.92))
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
        ctx.setFillColor(c("#F2D7D0"))
        var x = rect.minX + band * 0.6
        while x < rect.maxX - band * 0.4 {
            ctx.fillEllipse(in: CGRect(x: x - 0.3 * s, y: rect.minY + band * 0.42, width: 0.6 * s, height: 0.6 * s))
            ctx.fillEllipse(in: CGRect(x: x - 0.3 * s, y: rect.maxY - band * 0.42 - 0.6 * s, width: 0.6 * s, height: 0.6 * s))
            x += 1.8 * s
        }
        var y = rect.minY + band * 1.4
        while y < rect.maxY - band * 1.2 {
            ctx.fillEllipse(in: CGRect(x: rect.minX + band * 0.42, y: y - 0.3 * s, width: 0.6 * s, height: 0.6 * s))
            ctx.fillEllipse(in: CGRect(x: rect.maxX - band * 0.42 - 0.6 * s, y: y - 0.3 * s, width: 0.6 * s, height: 0.6 * s))
            y += 1.8 * s
        }
    }

    /// 情人节模板在空白处撒的小心形。
    private static func scatterHearts(_ ctx: CGContext, layout: PaperLayout, size: CGSize, s: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed ^ 0x4EA7)
        let windows = layout.windows.map { layout.scaled($0, toWidth: size.width).insetBy(dx: -0.8 * s, dy: -0.8 * s) }
        let caption = layout.scaled(layout.captionArea, toWidth: size.width)
        var placed = 0
        var attempts = 0
        while placed < 7, attempts < 200 {
            attempts += 1
            let w = CGFloat(rng.range(1.3, 2.4)) * s
            let x = CGFloat(rng.unit()) * (size.width - w * 2) + w
            let y = CGFloat(rng.unit()) * (size.height - w * 2) + w
            let rect = CGRect(x: x - w / 2, y: y - w / 2, width: w, height: w * 0.92)
            guard !windows.contains(where: { $0.intersects(rect) }), !caption.intersects(rect) else { continue }
            ctx.addPath(RetroPrint.heart(in: rect))
            ctx.setFillColor(placed % 2 == 0 ? c("#B8322A", 0.85) : c("#FFFFFF", 0.9))
            ctx.fillPath()
            placed += 1
        }
    }

    /// 金星模板：在边框上撒烫金星星（避开照片和题字）。
    private static func scatterStars(_ ctx: CGContext, layout: PaperLayout, size: CGSize, s: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed ^ 0x57A2)
        let windows = layout.windows.map { layout.scaled($0, toWidth: size.width).insetBy(dx: -0.3 * s, dy: -0.3 * s) }
        var placed = 0
        var attempts = 0
        let target = max(10, Int(size.height / s / 6))
        while placed < target, attempts < 600 {
            attempts += 1
            let r = CGFloat(rng.range(0.5, 1.4)) * s
            let center = CGPoint(x: CGFloat(rng.unit()) * size.width, y: CGFloat(rng.unit()) * size.height)
            let box = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            guard !windows.contains(where: { $0.intersects(box) }) else { continue }
            let four = rng.unit() < 0.4
            let star = RetroPrint.star(center: center, points: four ? 4 : 5, outer: r, inner: r * (four ? 0.32 : 0.42))
            ctx.saveGState()
            ctx.addPath(star)
            ctx.clip()
            if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#F6E3AE"), c("#C9A35A"), c("#8A6A30")] as CFArray, locations: [0, 0.55, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: box.minX, y: box.minY), end: CGPoint(x: box.maxX, y: box.maxY), options: [])
            }
            ctx.restoreGState()
            placed += 1
        }
    }

    /// 生日模板：顶上一串三角彩旗。
    private static func drawBunting(_ ctx: CGContext, spec: PrintSpec, rect: CGRect, s: CGFloat) {
        let layout = spec.layout
        let top = (layout.windows.first?.minY ?? 4) * s
        let flagH = min(top * 0.7, 3 * s)
        guard flagH > 1 else { return }
        let colors = ["#C4593B", "#D9A441", "#2F5F5C", "#E8B7A8"]
        let width = 2.6 * s
        ctx.setStrokeColor(c("#5A3A28", 0.6))
        ctx.setLineWidth(max(0.5, 0.12 * s))
        ctx.move(to: CGPoint(x: 0, y: top * 0.18))
        ctx.addQuadCurve(to: CGPoint(x: rect.maxX, y: top * 0.18), control: CGPoint(x: rect.midX, y: top * 0.18 + flagH * 0.3))
        ctx.strokePath()
        var x: CGFloat = 0.6 * s
        var i = 0
        while x + width < rect.maxX {
            let sag = flagH * 0.3 * (1 - pow((x + width / 2 - rect.midX) / (rect.width / 2), 2))
            let y0 = top * 0.18 + sag
            let flag = CGMutablePath()
            flag.addLines(between: [CGPoint(x: x, y: y0), CGPoint(x: x + width, y: y0), CGPoint(x: x + width / 2, y: y0 + flagH * 0.8)])
            flag.closeSubpath()
            ctx.addPath(flag)
            ctx.setFillColor(c(colors[i % colors.count]))
            ctx.fillPath()
            x += width + 0.6 * s
            i += 1
        }
    }

    /// 生日模板：每格照片下沿一条复古横幅。
    private static func banner(_ ctx: CGContext, window: CGRect, s: CGFloat, colorHex: String) {
        let height = min(window.height * 0.17, 4.2 * s)
        let width = window.width * 0.82
        let rect = CGRect(x: window.midX - width / 2, y: window.maxY - height * 0.7, width: width, height: height)
        let notch = height * 0.35
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: rect.minX - notch, y: rect.minY), CGPoint(x: rect.maxX + notch, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: rect.maxX + notch, y: rect.maxY),
            CGPoint(x: rect.minX - notch, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY)
        ])
        path.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.2 * s), blur: 0.6 * s, color: c("#000000", 0.35))
        ctx.addPath(path)
        ctx.setFillColor(c(colorHex))
        ctx.fillPath()
        ctx.restoreGState()
        RetroPrint.text(ctx, "HAPPY BIRTHDAY", fonts: RetroPrint.condensed, size: height * 0.62, color: c("#F6EFE1"), x: rect.midX, baseline: rect.midY + height * 0.22, maxWidth: width * 0.9, tracking: height * 0.08)
    }

    /// 新年模板：沿相纸边一圈金色回纹。
    private static func drawMeander(_ ctx: CGContext, rect: CGRect, s: CGFloat) {
        let unit = 1.4 * s
        let inset = 1.2 * s
        let frame = rect.insetBy(dx: inset, dy: inset)
        ctx.saveGState()
        ctx.setStrokeColor(c("#E3C98F", 0.95))
        ctx.setLineWidth(max(1, 0.28 * s))
        ctx.setLineJoin(.miter)
        func key(at origin: CGPoint, horizontal: Bool) {
            let u = unit
            let points: [CGPoint] = horizontal
                ? [CGPoint(x: 0, y: u), CGPoint(x: 0, y: 0), CGPoint(x: u * 1.5, y: 0), CGPoint(x: u * 1.5, y: u * 0.7), CGPoint(x: u * 0.6, y: u * 0.7), CGPoint(x: u * 0.6, y: u * 0.35), CGPoint(x: u * 1.05, y: u * 0.35)]
                : [CGPoint(x: u, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: u * 1.5), CGPoint(x: u * 0.7, y: u * 1.5), CGPoint(x: u * 0.7, y: u * 0.6), CGPoint(x: u * 0.35, y: u * 0.6), CGPoint(x: u * 0.35, y: u * 1.05)]
            ctx.move(to: CGPoint(x: origin.x + points[0].x, y: origin.y + points[0].y))
            for p in points.dropFirst() {
                ctx.addLine(to: CGPoint(x: origin.x + p.x, y: origin.y + p.y))
            }
        }
        var x = frame.minX
        while x + unit * 1.6 < frame.maxX {
            key(at: CGPoint(x: x, y: frame.minY), horizontal: true)
            key(at: CGPoint(x: x, y: frame.maxY - unit), horizontal: true)
            x += unit * 1.9
        }
        var y = frame.minY + unit * 1.4
        while y + unit * 1.6 < frame.maxY - unit {
            key(at: CGPoint(x: frame.minX, y: y), horizontal: false)
            key(at: CGPoint(x: frame.maxX - unit, y: y), horizontal: false)
            y += unit * 1.9
        }
        ctx.strokePath()
        ctx.restoreGState()
    }
}
