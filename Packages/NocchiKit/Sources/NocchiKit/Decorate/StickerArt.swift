import CoreGraphics
import CoreText
import Foundation

/// 贴纸的画法（Core Graphics，macOS / iOS 通用，线程安全）。
///
/// 每枚贴纸都在「设计坐标」里画：宽 100，高 100 / aspect，原点左上、y 向下。
/// 调用方传入的上下文必须是左上角原点（和 `PhotoComposer` 一样）。
public enum StickerArt {
    // 复古油墨
    static let mustard = "#D9A441"
    static let terracotta = "#C4593B"
    static let petrol = "#2F5F5C"
    static let cobalt = "#2F4C8A"
    static let cream = "#F2E6CF"
    static let paper = "#F6EFE1"
    static let ink = "#2E2924"
    static let red = "#B23A2A"
    static let brass = "#B8955A"
    static let olive = "#6F6A3A"
    static let navy = "#1E2A44"
    static let blush = "#E8B7A8"
    static let sky = "#9DB9D0"
    static let kraft = "#B9946A"
    static let walnut = "#5A3A28"

    // MARK: - 公开接口

    /// 自定义贴纸（「我的贴纸」，`custom.<UUID>`）的图：App 启动时注入，例如
    /// `StickerArt.customProvider = { store.art(forKindID: $0) }`。没注入或找不到图时，自定义贴纸不画。
    nonisolated(unsafe) public static var customProvider: (@Sendable (String) -> CustomStickerArt?)?

    /// 内置贴纸或自定义贴纸的种类（自定义的宽高比来自图片）。
    public static func kind(forID id: String) -> StickerKind? {
        if let builtIn = StickerCatalog.kind(id: id) { return builtIn }
        guard id.hasPrefix(CustomStickerStore.prefix), let art = customProvider?(id) else { return nil }
        return StickerKind(id: id, name: "", category: .badge, aspect: art.aspect, defaultSize: 0.25)
    }

    /// 在 rect 里画出贴纸。ctx 已是左上角原点、y 向下。
    public static func draw(_ kind: StickerKind, in ctx: CGContext, rect: CGRect, tint: RGB?, text: String?, seed: UInt64) {
        if kind.id.hasPrefix(CustomStickerStore.prefix) {
            if let art = customProvider?(kind.id) {
                drawCustom(art, in: ctx, rect: rect)
            }
            return
        }
        let height = 100 / CGFloat(max(kind.aspect, 0.05))
        let inkHex = tint.map { hex($0) } ?? kind.defaultTint ?? ink
        let words = (text?.isEmpty == false ? text : nil) ?? kind.defaultText
        RetroPrint.design(ctx, rect: rect) { ctx, px in
            let h = height
            switch kind.category {
            case .badge: drawBadge(kind.id, ctx, h, px, seed, words)
            case .stamp: drawStamp(kind.id, ctx, h, px, seed, inkHex, words)
            case .ephemera: drawEphemera(kind.id, ctx, h, px, seed, words)
            case .tape: drawTape(kind.id, ctx, h, px, seed)
            case .label: drawLabel(kind.id, ctx, h, px, seed, inkHex, words)
            case .emoji: drawEmoji(String(kind.id.dropFirst("emoji.".count)), ctx, h, px)
            }
        }
    }

    /// 按相纸上的摆放画一枚贴纸（中心、大小、顺时针旋转、水平翻转）。paperWidth 是相纸的像素宽度。
    public static func draw(_ placement: StickerPlacement, in ctx: CGContext, paperWidth: CGFloat) {
        guard let kind = Self.kind(forID: placement.kindID) else { return }
        let frame = frame(of: placement, paperWidth: paperWidth)
        guard frame.width > 1, frame.height > 1 else { return }
        ctx.saveGState()
        ctx.translateBy(x: frame.midX, y: frame.midY)
        ctx.rotate(by: CGFloat(placement.rotation) * .pi / 180)
        if placement.flipped {
            ctx.scaleBy(x: -1, y: 1)
        }
        let local = CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height)
        draw(kind, in: ctx, rect: local, tint: placement.tint.flatMap { RGB(hex: $0) }, text: placement.text, seed: placement.stableSeed)
        ctx.restoreGState()
    }

    /// 摆放的外框（未旋转，像素，左上原点）。
    public static func frame(of placement: StickerPlacement, paperWidth: CGFloat) -> CGRect {
        let aspect = CGFloat(Self.kind(forID: placement.kindID)?.aspect ?? 1)
        let width = CGFloat(placement.size) * paperWidth
        let height = width / max(aspect, 0.05)
        return CGRect(x: CGFloat(placement.x) * paperWidth - width / 2, y: CGFloat(placement.y) * paperWidth - height / 2, width: width, height: height)
    }

    /// 单独渲染成透明图（缩略图、装饰台的贴纸层）。
    public static func image(_ kind: StickerKind, pixelWidth: Int, tint: RGB?, text: String?, seed: UInt64) -> CGImage? {
        let width = max(8, pixelWidth)
        let height = max(8, Int((CGFloat(width) / CGFloat(max(kind.aspect, 0.05))).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        draw(kind, in: ctx, rect: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)), tint: tint, text: text, seed: seed)
        return ctx.makeImage()
    }

    /// 一枚摆好的贴纸单独渲染成透明图（装饰台上可拖动的那一层；内置和自定义都行）。
    public static func image(for placement: StickerPlacement, pixelWidth: Int) -> CGImage? {
        guard let kind = Self.kind(forID: placement.kindID) else { return nil }
        return image(kind, pixelWidth: pixelWidth, tint: placement.tint.flatMap { RGB(hex: $0) }, text: placement.text, seed: placement.stableSeed)
    }

    /// 自定义贴纸：图片本身（裁过透明边）+ 可选的白色模切边 + 柔和投影。rect 是像素。
    static func drawCustom(_ art: CustomStickerArt, in ctx: CGContext, rect: CGRect) {
        let u = max(rect.width, rect.height) / 100
        ctx.saveGState()
        ctx.interpolationQuality = .high
        if art.dieCut {
            let border = 2.6 * u
            let inner = rect.insetBy(dx: border + u * 0.6, dy: border + u * 0.6)
            ctx.setShadow(offset: CGSize(width: 0.5 * u, height: -1.1 * u), blur: 2.6 * u, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.3))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            for i in 0..<16 {
                let a = CGFloat(i) * .pi / 8
                drawUpright(ctx, art.image, in: inner.offsetBy(dx: cos(a) * border, dy: sin(a) * border))
            }
            drawUpright(ctx, art.image, in: inner)
            ctx.setBlendMode(.sourceIn)
            ctx.setFillColor(c("#FBF8F1"))
            ctx.fill(rect.insetBy(dx: -border, dy: -border))
            ctx.endTransparencyLayer()
            ctx.restoreGState()
            drawUpright(ctx, art.image, in: inner)
        } else {
            ctx.setShadow(offset: CGSize(width: 0.4 * u, height: -0.9 * u), blur: 2 * u, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.28))
            drawUpright(ctx, art.image, in: rect)
            ctx.restoreGState()
        }
    }

    static func hex(_ c: RGB) -> String {
        let r = Int((ColorMath.clamp01(c.x) * 255).rounded())
        let g = Int((ColorMath.clamp01(c.y) * 255).rounded())
        let b = Int((ColorMath.clamp01(c.z) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func c(_ hex: String, _ alpha: CGFloat = 1) -> CGColor { RetroPrint.color(hex, alpha) }

    private static func fill(_ ctx: CGContext, _ path: CGPath, _ hex: String, _ alpha: CGFloat = 1) {
        ctx.addPath(path)
        ctx.setFillColor(c(hex, alpha))
        ctx.fillPath()
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), transform: nil)
    }

    private static func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: min(r, rect.width / 2), cornerHeight: min(r, rect.height / 2), transform: nil)
    }

    /// 印刷质感：一层浅色网点高光 + 细颗粒。
    private static func printTexture(_ ctx: CGContext, _ h: CGFloat, _ seed: UInt64) {
        RetroPrint.speckle(ctx, rect: CGRect(x: 0, y: 0, width: 100, height: h), seed: seed, density: 0.8, alpha: 0.07, dark: true, size: 0.5)
        RetroPrint.speckle(ctx, rect: CGRect(x: 0, y: 0, width: 100, height: h), seed: seed &+ 7, density: 0.5, alpha: 0.1, dark: false, size: 0.5)
    }

    // MARK: - 徽章

    private static func drawBadge(_ id: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat, _ seed: UInt64, _ text: String?) {
        let disc = circle(50, h / 2, 44)
        switch id {
        case "badge.sun":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, cream)
                for i in 0..<16 {
                    let a0 = CGFloat(i) * .pi / 8
                    let ray = CGMutablePath()
                    ray.move(to: CGPoint(x: 50 + cos(a0 - 0.12) * 20, y: h / 2 + sin(a0 - 0.12) * 20))
                    ray.addLine(to: CGPoint(x: 50 + cos(a0) * 46, y: h / 2 + sin(a0) * 46))
                    ray.addLine(to: CGPoint(x: 50 + cos(a0 + 0.12) * 20, y: h / 2 + sin(a0 + 0.12) * 20))
                    ray.closeSubpath()
                    fill(ctx, ray, i % 2 == 0 ? terracotta : mustard)
                }
                fill(ctx, circle(50.7, h / 2 + 0.5, 21), terracotta, 0.55)
                fill(ctx, circle(50, h / 2, 21), mustard)
                fill(ctx, circle(50, h / 2, 15), "#E8B653")
                fill(ctx, circle(44, h / 2 - 7, 4.5), "#FFF4D6", 0.7)
                printTexture(ctx, h, seed)
            }
        case "badge.rain":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, sky)
                RetroPrint.halftone(ctx, rect: CGRect(x: 0, y: h * 0.6, width: 100, height: h * 0.4), spacing: 3.4, radius: 0.8, color: c(cobalt, 0.25))
                let cloud = CGMutablePath()
                cloud.addPath(circle(36, h / 2 - 4, 13))
                cloud.addPath(circle(52, h / 2 - 12, 16))
                cloud.addPath(circle(66, h / 2 - 3, 12))
                cloud.addPath(rounded(CGRect(x: 24, y: h / 2 - 4, width: 54, height: 14), 7))
                fill(ctx, cloud, "#E9EEF0")
                for (i, x) in [32, 44, 56, 68].enumerated() {
                    let drop = CGMutablePath()
                    let top = h / 2 + 18 + CGFloat(i % 2) * 6
                    drop.move(to: CGPoint(x: CGFloat(x), y: top))
                    drop.addCurve(to: CGPoint(x: CGFloat(x), y: top + 13), control1: CGPoint(x: CGFloat(x) + 6, y: top + 7), control2: CGPoint(x: CGFloat(x) + 5, y: top + 13))
                    drop.addCurve(to: CGPoint(x: CGFloat(x), y: top), control1: CGPoint(x: CGFloat(x) - 5, y: top + 13), control2: CGPoint(x: CGFloat(x) - 6, y: top + 7))
                    fill(ctx, drop, cobalt)
                }
                printTexture(ctx, h, seed)
            }
        case "badge.bolt":
            let bolt = CGMutablePath()
            bolt.addLines(between: [CGPoint(x: 60, y: 5), CGPoint(x: 15, y: 72), CGPoint(x: 46, y: 72), CGPoint(x: 33, y: 120), CGPoint(x: 87, y: 46), CGPoint(x: 56, y: 46), CGPoint(x: 74, y: 5)])
            bolt.closeSubpath()
            RetroPrint.vinyl(ctx, shape: bolt, border: 3.2, px: px) { ctx in
                fill(ctx, bolt, mustard)
                ctx.saveGState()
                ctx.translateBy(x: 3, y: 2.5)
                fill(ctx, bolt, terracotta, 0.6)
                ctx.restoreGState()
                fill(ctx, bolt, "#E3B24C")
                ctx.addPath(bolt)
                ctx.setStrokeColor(c(ink, 0.85))
                ctx.setLineWidth(2.4)
                ctx.setLineJoin(.round)
                ctx.strokePath()
                printTexture(ctx, h, seed)
            }
        case "badge.coffee":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, terracotta)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 22, y: h / 2 + 18, width: 56, height: 12), transform: nil), "#E6D6BC")
                let cup = CGMutablePath()
                cup.move(to: CGPoint(x: 28, y: h / 2 - 4))
                cup.addLine(to: CGPoint(x: 72, y: h / 2 - 4))
                cup.addCurve(to: CGPoint(x: 50, y: h / 2 + 24), control1: CGPoint(x: 72, y: h / 2 + 14), control2: CGPoint(x: 62, y: h / 2 + 24))
                cup.addCurve(to: CGPoint(x: 28, y: h / 2 - 4), control1: CGPoint(x: 38, y: h / 2 + 24), control2: CGPoint(x: 28, y: h / 2 + 14))
                fill(ctx, cup, cream)
                ctx.addPath(circle(73, h / 2 + 6, 7))
                ctx.setStrokeColor(c(cream))
                ctx.setLineWidth(3.6)
                ctx.strokePath()
                fill(ctx, CGPath(ellipseIn: CGRect(x: 30, y: h / 2 - 7, width: 40, height: 6), transform: nil), walnut)
                ctx.setLineCap(.round)
                ctx.setLineWidth(2.6)
                ctx.setStrokeColor(c(cream, 0.9))
                for dx in [-9, 0, 9] {
                    let steam = CGMutablePath()
                    let x = 50 + CGFloat(dx)
                    steam.move(to: CGPoint(x: x, y: h / 2 - 12))
                    steam.addCurve(to: CGPoint(x: x, y: h / 2 - 30), control1: CGPoint(x: x - 6, y: h / 2 - 18), control2: CGPoint(x: x + 6, y: h / 2 - 24))
                    ctx.addPath(steam)
                    ctx.strokePath()
                }
                printTexture(ctx, h, seed)
            }
        case "badge.dog":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, mustard)
                ctx.saveGState()
                ctx.translateBy(x: 26, y: h / 2 - 12)
                ctx.rotate(by: 0.35)
                fill(ctx, CGPath(ellipseIn: CGRect(x: -8, y: -4, width: 16, height: 30), transform: nil), walnut)
                ctx.restoreGState()
                ctx.saveGState()
                ctx.translateBy(x: 74, y: h / 2 - 12)
                ctx.rotate(by: -0.35)
                fill(ctx, CGPath(ellipseIn: CGRect(x: -8, y: -4, width: 16, height: 30), transform: nil), walnut)
                ctx.restoreGState()
                fill(ctx, circle(50, h / 2 + 2, 24), cream)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 38, y: h / 2 + 4, width: 24, height: 18), transform: nil), "#E8D8BE")
                fill(ctx, circle(41, h / 2 - 4, 3.2), ink)
                fill(ctx, circle(59, h / 2 - 4, 3.2), ink)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 45, y: h / 2 + 5, width: 10, height: 7), transform: nil), ink)
                fill(ctx, rounded(CGRect(x: 46.5, y: h / 2 + 14, width: 7, height: 9), 3.5), terracotta)
                printTexture(ctx, h, seed)
            }
        case "badge.cat":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, petrol)
                for side: CGFloat in [-1, 1] {
                    let ear = CGMutablePath()
                    ear.addLines(between: [CGPoint(x: 50 + side * 8, y: h / 2 - 16), CGPoint(x: 50 + side * 26, y: h / 2 - 30), CGPoint(x: 50 + side * 24, y: h / 2 - 6)])
                    ear.closeSubpath()
                    fill(ctx, ear, cream)
                    let inner = CGMutablePath()
                    inner.addLines(between: [CGPoint(x: 50 + side * 13, y: h / 2 - 15), CGPoint(x: 50 + side * 23, y: h / 2 - 24), CGPoint(x: 50 + side * 22, y: h / 2 - 11)])
                    inner.closeSubpath()
                    fill(ctx, inner, blush)
                }
                fill(ctx, CGPath(ellipseIn: CGRect(x: 25, y: h / 2 - 18, width: 50, height: 42), transform: nil), cream)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 37, y: h / 2 - 6, width: 7, height: 9), transform: nil), ink)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 56, y: h / 2 - 6, width: 7, height: 9), transform: nil), ink)
                let nose = CGMutablePath()
                nose.addLines(between: [CGPoint(x: 47, y: h / 2 + 6), CGPoint(x: 53, y: h / 2 + 6), CGPoint(x: 50, y: h / 2 + 10)])
                nose.closeSubpath()
                fill(ctx, nose, terracotta)
                ctx.setStrokeColor(c(ink, 0.7))
                ctx.setLineWidth(1)
                for (y0, y1) in [(CGFloat(8), CGFloat(6)), (12, 13)] {
                    ctx.move(to: CGPoint(x: 40, y: h / 2 + y0))
                    ctx.addLine(to: CGPoint(x: 26, y: h / 2 + y1))
                    ctx.move(to: CGPoint(x: 60, y: h / 2 + y0))
                    ctx.addLine(to: CGPoint(x: 74, y: h / 2 + y1))
                }
                ctx.strokePath()
                printTexture(ctx, h, seed)
            }
        case "badge.heart":
            let heart = RetroPrint.heart(in: CGRect(x: 6, y: 7, width: 88, height: h - 12))
            RetroPrint.vinyl(ctx, shape: heart, border: 2.6, px: px) { ctx in
                drawBrass(ctx, heart, CGRect(x: 0, y: 0, width: 100, height: h))
                ctx.saveGState()
                ctx.translateBy(x: 50, y: h / 2)
                ctx.scaleBy(x: 0.8, y: 0.8)
                ctx.translateBy(x: -50, y: -h / 2)
                fill(ctx, heart, "#B8322A")
                ctx.addPath(heart)
                ctx.clip()
                if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#FFFFFF", 0.45), c("#FFFFFF", 0)] as CFArray, locations: [0, 1]) {
                    ctx.drawLinearGradient(g, start: CGPoint(x: 20, y: 10), end: CGPoint(x: 50, y: h * 0.55), options: [])
                }
                ctx.restoreGState()
                fill(ctx, CGPath(ellipseIn: CGRect(x: 26, y: 20, width: 14, height: 9), transform: nil), "#FFFFFF", 0.55)
            }
        case "badge.new":
            let burst = RetroPrint.star(center: CGPoint(x: 50, y: h / 2), points: 18, outer: 46, inner: 38)
            RetroPrint.vinyl(ctx, shape: burst, border: 2.6, px: px) { ctx in
                fill(ctx, burst, red)
                ctx.addPath(circle(50, h / 2, 31))
                ctx.setStrokeColor(c(cream, 0.9))
                ctx.setLineWidth(1.4)
                ctx.strokePath()
                let word = (text ?? "NEW!").uppercased()
                RetroPrint.text(ctx, word, fonts: RetroPrint.condensed, size: 26, color: c(terracotta, 0.6), x: 51, baseline: h / 2 + 10, maxWidth: 58)
                RetroPrint.text(ctx, word, fonts: RetroPrint.condensed, size: 26, color: c(cream), x: 50, baseline: h / 2 + 9.5, maxWidth: 58)
                printTexture(ctx, h, seed)
            }
        case "badge.rainbow":
            let pill = rounded(CGRect(x: 5, y: 5, width: 90, height: h - 10), (h - 10) / 2)
            RetroPrint.vinyl(ctx, shape: pill, border: 2.6, px: px) { ctx in
                fill(ctx, pill, cream)
                let center = CGPoint(x: 50, y: h - 8)
                ctx.setLineCap(.butt)
                for (i, hexColor) in [terracotta, mustard, petrol].enumerated() {
                    let radius = 36 - CGFloat(i) * 9
                    ctx.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
                    ctx.setStrokeColor(c(hexColor))
                    ctx.setLineWidth(8.4)
                    ctx.strokePath()
                }
                for x in [CGFloat(14), 86] {
                    let puff = CGMutablePath()
                    puff.addPath(circle(x - 6, h - 12, 6))
                    puff.addPath(circle(x + 2, h - 15, 7.5))
                    puff.addPath(circle(x + 9, h - 11, 5.5))
                    fill(ctx, puff, "#FFFDF7")
                }
                printTexture(ctx, h, seed)
            }
        case "badge.cherry":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, cream)
                ctx.setStrokeColor(c(olive))
                ctx.setLineWidth(2.6)
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 36, y: h / 2 + 8))
                ctx.addQuadCurve(to: CGPoint(x: 56, y: h / 2 - 26), control: CGPoint(x: 40, y: h / 2 - 14))
                ctx.move(to: CGPoint(x: 64, y: h / 2 + 12))
                ctx.addQuadCurve(to: CGPoint(x: 56, y: h / 2 - 26), control: CGPoint(x: 66, y: h / 2 - 8))
                ctx.strokePath()
                ctx.saveGState()
                ctx.translateBy(x: 62, y: h / 2 - 26)
                ctx.rotate(by: -0.5)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 0, y: -5, width: 20, height: 10), transform: nil), olive)
                ctx.restoreGState()
                for (x, y) in [(CGFloat(36), h / 2 + 14), (64, h / 2 + 18)] {
                    fill(ctx, circle(x + 1, y + 1, 12), "#7A1E1A", 0.5)
                    fill(ctx, circle(x, y, 12), red)
                    fill(ctx, circle(x - 4, y - 4, 3.2), "#FFFFFF", 0.6)
                }
                printTexture(ctx, h, seed)
            }
        case "badge.lemon":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, mustard)
                fill(ctx, circle(50, h / 2, 39), "#FFF6D8")
                fill(ctx, circle(50, h / 2, 35), "#F2D45C")
                ctx.setStrokeColor(c("#FFF6D8"))
                ctx.setLineWidth(2.2)
                for i in 0..<10 {
                    let a = CGFloat(i) * .pi / 5
                    ctx.move(to: CGPoint(x: 50, y: h / 2))
                    ctx.addLine(to: CGPoint(x: 50 + cos(a) * 35, y: h / 2 + sin(a) * 35))
                }
                ctx.strokePath()
                fill(ctx, circle(50, h / 2, 5), "#FFF6D8")
                RetroPrint.halftone(ctx, rect: CGRect(x: 0, y: 0, width: 100, height: h), spacing: 4, radius: 0.55, color: c("#FFFFFF", 0.25))
                printTexture(ctx, h, seed)
            }
        case "badge.daisy":
            let flower = CGMutablePath()
            for i in 0..<12 {
                let a = CGFloat(i) * .pi / 6
                var t = CGAffineTransform(translationX: 50, y: h / 2).rotated(by: a)
                flower.addPath(CGPath(ellipseIn: CGRect(x: 8, y: -7, width: 36, height: 14), transform: &t))
            }
            flower.addPath(circle(50, h / 2, 14))
            RetroPrint.vinyl(ctx, shape: flower, border: 2.4, px: px) { ctx in
                fill(ctx, CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: h), transform: nil), "#FBF6EA")
                fill(ctx, circle(50, h / 2, 14), mustard)
                RetroPrint.halftone(ctx, rect: CGRect(x: 36, y: h / 2 - 14, width: 28, height: 28), spacing: 3, radius: 0.7, color: c(terracotta, 0.5))
                printTexture(ctx, h, seed)
            }
        case "badge.camera":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, mustard)
                fill(ctx, rounded(CGRect(x: 22, y: h / 2 - 16, width: 56, height: 36), 6), ink)
                fill(ctx, rounded(CGRect(x: 30, y: h / 2 - 22, width: 16, height: 8), 2), ink)
                fill(ctx, rounded(CGRect(x: 60, y: h / 2 - 12, width: 12, height: 6), 1.5), "#E6E2D6")
                fill(ctx, circle(50, h / 2 + 2, 14), "#E6E2D6")
                fill(ctx, circle(50, h / 2 + 2, 11), ink)
                fill(ctx, circle(50, h / 2 + 2, 6), "#3B4A5A")
                fill(ctx, circle(47, h / 2 - 1, 2.2), "#FFFFFF", 0.7)
                fill(ctx, circle(68, h / 2 - 20, 3.5), terracotta)
                printTexture(ctx, h, seed)
            }
        case "badge.film":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, petrol)
                fill(ctx, rounded(CGRect(x: 58, y: h / 2 - 8, width: 22, height: 18), 2), walnut)
                fill(ctx, rounded(CGRect(x: 32, y: h / 2 - 20, width: 30, height: 42), 3), cream)
                fill(ctx, CGPath(rect: CGRect(x: 32, y: h / 2 - 6, width: 30, height: 8), transform: nil), terracotta)
                fill(ctx, rounded(CGRect(x: 30, y: h / 2 - 24, width: 34, height: 6), 2), "#B9B4AA")
                fill(ctx, rounded(CGRect(x: 30, y: h / 2 + 20, width: 34, height: 6), 2), "#B9B4AA")
                fill(ctx, rounded(CGRect(x: 42, y: h / 2 - 29, width: 10, height: 6), 2), ink)
                RetroPrint.text(ctx, "400", fonts: RetroPrint.condensed, size: 9, color: c(ink), x: 47, baseline: h / 2 + 15)
                printTexture(ctx, h, seed)
            }
        case "badge.moon":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, navy)
                fill(ctx, circle(46, h / 2, 22), cream)
                fill(ctx, circle(56, h / 2 - 6, 19), navy)
                for (x, y, r) in [(CGFloat(70), h / 2 + 14, CGFloat(5)), (64, h / 2 - 22, 3.5), (30, h / 2 - 24, 3)] {
                    fill(ctx, RetroPrint.star(center: CGPoint(x: x, y: y), points: 4, outer: r, inner: r * 0.36), mustard)
                }
                printTexture(ctx, h, seed)
            }
        case "badge.cake":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, blush)
                fill(ctx, rounded(CGRect(x: 24, y: h / 2 - 2, width: 52, height: 26), 3), cream)
                fill(ctx, CGPath(rect: CGRect(x: 24, y: h / 2 + 7, width: 52, height: 6), transform: nil), terracotta)
                fill(ctx, rounded(CGRect(x: 20, y: h / 2 + 22, width: 60, height: 5), 2.5), "#FFFDF7")
                for x in [CGFloat(36), 50, 64] {
                    fill(ctx, CGPath(rect: CGRect(x: x - 2, y: h / 2 - 16, width: 4, height: 14), transform: nil), cobalt)
                    let flame = CGMutablePath()
                    flame.move(to: CGPoint(x: x, y: h / 2 - 27))
                    flame.addQuadCurve(to: CGPoint(x: x, y: h / 2 - 17), control: CGPoint(x: x + 5, y: h / 2 - 19))
                    flame.addQuadCurve(to: CGPoint(x: x, y: h / 2 - 27), control: CGPoint(x: x - 5, y: h / 2 - 19))
                    fill(ctx, flame, mustard)
                }
                printTexture(ctx, h, seed)
            }
        case "badge.music":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, ink)
                fill(ctx, CGPath(ellipseIn: CGRect(x: 30, y: h / 2 + 8, width: 18, height: 13), transform: nil), cream)
                fill(ctx, CGPath(rect: CGRect(x: 44, y: h / 2 - 26, width: 4, height: 40), transform: nil), cream)
                let flag = CGMutablePath()
                flag.move(to: CGPoint(x: 48, y: h / 2 - 26))
                flag.addCurve(to: CGPoint(x: 66, y: h / 2), control1: CGPoint(x: 60, y: h / 2 - 20), control2: CGPoint(x: 70, y: h / 2 - 12))
                flag.addCurve(to: CGPoint(x: 48, y: h / 2 - 14), control1: CGPoint(x: 64, y: h / 2 - 10), control2: CGPoint(x: 56, y: h / 2 - 14))
                flag.closeSubpath()
                fill(ctx, flag, mustard)
                printTexture(ctx, h, seed)
            }
        case "badge.plane":
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, sky)
                ctx.saveGState()
                ctx.translateBy(x: 50, y: h / 2)
                ctx.rotate(by: -0.45)
                fill(ctx, rounded(CGRect(x: -30, y: -5, width: 60, height: 10), 5), cream)
                let wing = CGMutablePath()
                wing.addLines(between: [CGPoint(x: -4, y: -4), CGPoint(x: 6, y: -26), CGPoint(x: 13, y: -26), CGPoint(x: 9, y: -4)])
                wing.closeSubpath()
                fill(ctx, wing, cream)
                var mirror = CGAffineTransform(scaleX: 1, y: -1)
                if let lower = wing.copy(using: &mirror) {
                    fill(ctx, lower, cream)
                }
                let tail = CGMutablePath()
                tail.addLines(between: [CGPoint(x: -28, y: -3), CGPoint(x: -24, y: -14), CGPoint(x: -20, y: -14), CGPoint(x: -21, y: -3)])
                tail.closeSubpath()
                fill(ctx, tail, terracotta)
                ctx.restoreGState()
                printTexture(ctx, h, seed)
            }
        default:
            RetroPrint.vinyl(ctx, shape: disc, border: 3, px: px) { ctx in
                fill(ctx, disc, mustard)
            }
        }
    }

    /// 黄铜描边（珐琅章的金属边）。
    private static func drawBrass(_ ctx: CGContext, _ shape: CGPath, _ bounds: CGRect) {
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#F3DEA4"), c(brass), c("#7A5A2E"), c("#E3C98F")] as CFArray, locations: [0, 0.35, 0.7, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: bounds.minX, y: bounds.minY), end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [])
        }
        ctx.restoreGState()
    }

    // MARK: - 印章

    private static func drawStamp(_ id: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat, _ seed: UInt64, _ inkHex: String, _ text: String?) {
        let inkColor = c(inkHex, 0.9)
        let bounds = CGRect(x: 0, y: 0, width: 100, height: h)
        ctx.saveGState()
        ctx.setAlpha(0.92)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setStrokeColor(inkColor)
        ctx.setFillColor(inkColor)
        switch id {
        case "stamp.postmark":
            let r: CGFloat = min(h / 2 - 4, 28)
            let center = CGPoint(x: 4 + r, y: h / 2)
            ctx.setLineWidth(2.2)
            ctx.addPath(circle(center.x, center.y, r))
            ctx.strokePath()
            ctx.setLineWidth(1)
            ctx.addPath(circle(center.x, center.y, r - 4.5))
            ctx.strokePath()
            let parts = (text ?? "NOCCHI").components(separatedBy: " · ")
            let top = parts.count > 1 ? parts[0] : "NOCCHI"
            let middle = parts.count > 1 ? parts[1] : (parts.first ?? "")
            let span = RetroPrint.arcSpan(top, fonts: RetroPrint.typewriter, size: 8, radius: r - 10, spacing: 0.8)
            RetroPrint.arcText(ctx, top, fonts: RetroPrint.typewriter, size: 8, color: inkColor, center: center, radius: r - 10, startAngle: -.pi / 2 - span / 2, spacing: 0.8)
            RetroPrint.text(ctx, middle, fonts: RetroPrint.typewriter, size: 7, color: inkColor, x: center.x, baseline: center.y + 4, maxWidth: r * 1.5)
            ctx.setLineWidth(1.6)
            for i in 0..<5 {
                let y = h / 2 - 14 + CGFloat(i) * 7
                ctx.move(to: CGPoint(x: center.x + r + 4, y: y))
                var x = center.x + r + 4
                while x < 98 {
                    ctx.addQuadCurve(to: CGPoint(x: x + 8, y: y), control: CGPoint(x: x + 4, y: y + (Int((x / 8).rounded()) % 2 == 0 ? -3 : 3)))
                    x += 8
                }
            }
            ctx.strokePath()
        case "stamp.ok":
            ctx.setLineWidth(3)
            ctx.addPath(rounded(CGRect(x: 6, y: 6, width: 88, height: h - 12), 10))
            ctx.strokePath()
            ctx.setLineWidth(1.2)
            ctx.addPath(rounded(CGRect(x: 11, y: 11, width: 78, height: h - 22), 7))
            ctx.strokePath()
            RetroPrint.text(ctx, "OK!", fonts: RetroPrint.condensed, size: 34, color: inkColor, x: 50, baseline: h / 2 + 12, maxWidth: 70)
        case "stamp.love":
            ctx.setLineWidth(2.6)
            ctx.addEllipse(in: CGRect(x: 5, y: 5, width: 90, height: h - 10))
            ctx.strokePath()
            ctx.setLineWidth(1)
            ctx.addEllipse(in: CGRect(x: 10, y: 10, width: 80, height: h - 20))
            ctx.strokePath()
            RetroPrint.text(ctx, "LOVE", fonts: RetroPrint.serifBold, size: 24, color: inkColor, x: 50, baseline: h / 2 + 8, maxWidth: 56, tracking: 1.5)
            ctx.addPath(RetroPrint.heart(in: CGRect(x: 13, y: h / 2 - 4, width: 8, height: 7.5)))
            ctx.addPath(RetroPrint.heart(in: CGRect(x: 79, y: h / 2 - 4, width: 8, height: 7.5)))
            ctx.fillPath()
        case "stamp.developed":
            ctx.setLineWidth(2.4)
            ctx.stroke(CGRect(x: 4, y: 4, width: 92, height: h - 8))
            ctx.setLineWidth(0.9)
            ctx.stroke(CGRect(x: 8, y: 8, width: 84, height: h - 16))
            RetroPrint.text(ctx, "已显影", fonts: RetroPrint.chineseSerif, size: 20, color: inkColor, x: 50, baseline: h / 2 + 3, maxWidth: 76, tracking: 3) // i18n-ok：贴纸上印的字（图案的一部分）
            RetroPrint.text(ctx, "DEVELOPED · NOCCHI", fonts: RetroPrint.typewriter, size: 5.6, color: inkColor, x: 50, baseline: h - 12, maxWidth: 76, tracking: 0.6)
        case "stamp.seal":
            ctx.addPath(rounded(CGRect(x: 7, y: 7, width: 86, height: 86), 6))
            ctx.fillPath()
            ctx.setBlendMode(.destinationOut)
            RetroPrint.text(ctx, "珍", fonts: RetroPrint.chineseSerif, size: 38, color: c("#000000"), x: 30, baseline: 64) // i18n-ok：贴纸上印的字（图案的一部分）
            RetroPrint.text(ctx, "藏", fonts: RetroPrint.chineseSerif, size: 38, color: c("#000000"), x: 70, baseline: 64) // i18n-ok：贴纸上印的字（图案的一部分）
            ctx.setLineWidth(2)
            ctx.setStrokeColor(c("#000000"))
            ctx.addPath(rounded(CGRect(x: 13, y: 13, width: 74, height: 74), 3))
            ctx.strokePath()
            ctx.setBlendMode(.normal)
        case "stamp.sunny":
            ctx.setLineWidth(2.2)
            ctx.addPath(circle(50, 50, 42))
            ctx.strokePath()
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            for i in 0..<12 {
                let a = CGFloat(i) * .pi / 6
                ctx.move(to: CGPoint(x: 50 + cos(a) * 31, y: 50 + sin(a) * 31))
                ctx.addLine(to: CGPoint(x: 50 + cos(a) * 37, y: 50 + sin(a) * 37))
            }
            ctx.strokePath()
            RetroPrint.text(ctx, "好天气", fonts: RetroPrint.chineseSerif, size: 15, color: inkColor, x: 50, baseline: 55, maxWidth: 52) // i18n-ok：贴纸上印的字（图案的一部分）
            RetroPrint.text(ctx, "FINE DAY", fonts: RetroPrint.typewriter, size: 5.5, color: inkColor, x: 50, baseline: 66, maxWidth: 50, tracking: 0.8)
        case "stamp.best":
            let ribbon = CGMutablePath()
            ribbon.addLines(between: [CGPoint(x: 2, y: 6), CGPoint(x: 98, y: 6), CGPoint(x: 92, y: h / 2), CGPoint(x: 98, y: h - 6), CGPoint(x: 2, y: h - 6), CGPoint(x: 8, y: h / 2)])
            ribbon.closeSubpath()
            ctx.setLineWidth(2.2)
            ctx.addPath(ribbon)
            ctx.strokePath()
            RetroPrint.text(ctx, "★ BEST ★", fonts: RetroPrint.condensed, size: 20, color: inkColor, x: 50, baseline: h / 2 + 7, maxWidth: 76, tracking: 1)
        case "stamp.lab":
            let frame = CGMutablePath()
            frame.addLines(between: [CGPoint(x: 10, y: 4), CGPoint(x: 90, y: 4), CGPoint(x: 96, y: 10), CGPoint(x: 96, y: h - 10), CGPoint(x: 90, y: h - 4), CGPoint(x: 10, y: h - 4), CGPoint(x: 4, y: h - 10), CGPoint(x: 4, y: 10)])
            frame.closeSubpath()
            ctx.setLineWidth(2.2)
            ctx.addPath(frame)
            ctx.strokePath()
            RetroPrint.text(ctx, "NOCCHI PHOTO LAB", fonts: RetroPrint.typewriter, size: 6, color: inkColor, x: 50, baseline: 14, maxWidth: 80, tracking: 0.8)
            RetroPrint.text(ctx, "冲印店", fonts: RetroPrint.chineseSerif, size: 20, color: inkColor, x: 50, baseline: h / 2 + 7, maxWidth: 80, tracking: 4) // i18n-ok：贴纸上印的字（图案的一部分）
            RetroPrint.text(ctx, "EST. 2026", fonts: RetroPrint.typewriter, size: 5.5, color: inkColor, x: 50, baseline: h - 9, maxWidth: 80, tracking: 1)
        case "stamp.date":
            ctx.setLineWidth(1.6)
            ctx.addPath(rounded(CGRect(x: 4, y: 5, width: 92, height: h - 10), 3))
            ctx.strokePath()
            RetroPrint.text(ctx, text ?? "2026 NOV 23", fonts: ["Courier-Bold", "AmericanTypewriter-Bold"], size: 17, color: inkColor, x: 50, baseline: h / 2 + 6, maxWidth: 84, tracking: 1)
        default:
            break
        }
        RetroPrint.distress(ctx, rect: bounds, seed: seed, amount: 1)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    // MARK: - 旧物

    private static func drawEphemera(_ id: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat, _ seed: UInt64, _ text: String?) {
        var rng = SeededRandom(seed: seed ^ 0xE9E)
        let number = String(format: "No. %04d", Int(rng.range(1, 9999)))
        switch id {
        case "ephemera.ticket":
            let ticket = CGMutablePath()
            let r: CGFloat = 5
            ticket.move(to: CGPoint(x: 4 + r, y: 4))
            ticket.addLine(to: CGPoint(x: 96 - r, y: 4))
            ticket.addArc(center: CGPoint(x: 96, y: 4), radius: r, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
            ticket.addLine(to: CGPoint(x: 96, y: h - 4 - r))
            ticket.addArc(center: CGPoint(x: 96, y: h - 4), radius: r, startAngle: 3 * .pi / 2, endAngle: .pi, clockwise: true)
            ticket.addLine(to: CGPoint(x: 4 + r, y: h - 4))
            ticket.addArc(center: CGPoint(x: 4, y: h - 4), radius: r, startAngle: 0, endAngle: -.pi / 2, clockwise: true)
            ticket.addLine(to: CGPoint(x: 4, y: 4 + r))
            ticket.addArc(center: CGPoint(x: 4, y: 4), radius: r, startAngle: .pi / 2, endAngle: 0, clockwise: true)
            ticket.closeSubpath()
            RetroPrint.paperShadow(ctx, shape: ticket, px: px, fill: c("#EBCDB9"))
            ctx.saveGState()
            ctx.addPath(ticket)
            ctx.clip()
            RetroPrint.speckle(ctx, rect: CGRect(x: 0, y: 0, width: 100, height: h), seed: seed, density: 1, alpha: 0.08)
            ctx.setStrokeColor(c(red, 0.85))
            ctx.setLineWidth(0.8)
            ctx.stroke(CGRect(x: 9, y: 8, width: 64, height: h - 16))
            RetroPrint.text(ctx, "ADMIT ONE", fonts: RetroPrint.condensed, size: 15, color: c(red), x: 41, baseline: h / 2 + 2, maxWidth: 58, tracking: 0.8)
            RetroPrint.text(ctx, "NOCCHI CINEMA", fonts: RetroPrint.typewriter, size: 4.6, color: c(ink, 0.8), x: 41, baseline: h / 2 + 10, maxWidth: 58, tracking: 0.6)
            ctx.setFillColor(c(ink, 0.45))
            var y: CGFloat = 7
            while y < h - 5 {
                ctx.fillEllipse(in: CGRect(x: 77, y: y, width: 1.2, height: 1.2))
                y += 3.2
            }
            ctx.saveGState()
            ctx.translateBy(x: 88, y: h / 2)
            ctx.rotate(by: -.pi / 2)
            RetroPrint.text(ctx, number, fonts: RetroPrint.typewriter, size: 5.5, color: c(red, 0.9), x: 0, baseline: 2, maxWidth: h - 10)
            ctx.restoreGState()
            ctx.restoreGState()
        case "ephemera.stamp":
            let outer = CGRect(x: 6, y: 6, width: 88, height: h - 12)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0.4 * px, height: -0.9 * px), blur: 2 * px, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.28))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setFillColor(c("#F8F2E2"))
            ctx.fill(outer)
            let picture = CGRect(x: 15, y: 15, width: 70, height: h - 42)
            ctx.saveGState()
            ctx.clip(to: picture)
            if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#E9C08A"), c("#F3E3C1")] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: picture.minY), end: CGPoint(x: 0, y: picture.maxY), options: [])
            }
            fill(ctx, circle(62, picture.minY + picture.height * 0.4, 11), terracotta)
            let hills = CGMutablePath()
            hills.move(to: CGPoint(x: picture.minX, y: picture.maxY))
            hills.addCurve(to: CGPoint(x: picture.maxX, y: picture.minY + picture.height * 0.62), control1: CGPoint(x: 40, y: picture.minY + picture.height * 0.4), control2: CGPoint(x: 60, y: picture.maxY))
            hills.addLine(to: CGPoint(x: picture.maxX, y: picture.maxY))
            hills.closeSubpath()
            fill(ctx, hills, petrol)
            RetroPrint.halftone(ctx, rect: picture, spacing: 3, radius: 0.5, color: c(ink, 0.12))
            ctx.restoreGState()
            ctx.setStrokeColor(c(ink, 0.6))
            ctx.setLineWidth(0.6)
            ctx.stroke(picture)
            RetroPrint.text(ctx, "8分", fonts: RetroPrint.chineseSerif, size: 9, color: c(red), x: 18, baseline: picture.minY + 10, align: -1) // i18n-ok：贴纸上印的字（图案的一部分）
            RetroPrint.text(ctx, "NOCCHI POST", fonts: RetroPrint.typewriter, size: 6.5, color: c(ink, 0.85), x: 50, baseline: h - 17, maxWidth: 70, tracking: 0.8)
            RetroPrint.punch(ctx, RetroPrint.perforations(outer, hole: 2.6, spacing: 7))
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        case "ephemera.pricetag", "ephemera.luggage":
            let luggage = id == "ephemera.luggage"
            let tag = CGMutablePath()
            tag.addLines(between: [CGPoint(x: 26, y: 6), CGPoint(x: 74, y: 6), CGPoint(x: 94, y: 26), CGPoint(x: 94, y: h - 6), CGPoint(x: 6, y: h - 6), CGPoint(x: 6, y: 26)])
            tag.closeSubpath()
            let hole = circle(50, 22, 5)
            let shape = CGMutablePath()
            shape.addPath(tag)
            shape.addPath(hole)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0.4 * px, height: -0.9 * px), blur: 2 * px, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.28))
            ctx.addPath(shape)
            ctx.setFillColor(c(luggage ? kraft : "#F3EAD6"))
            ctx.fillPath(using: .evenOdd)
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(shape)
            ctx.clip(using: .evenOdd)
            RetroPrint.speckle(ctx, rect: CGRect(x: 0, y: 0, width: 100, height: h), seed: seed, density: 1.2, alpha: luggage ? 0.12 : 0.07)
            ctx.restoreGState()
            ctx.setStrokeColor(c(luggage ? walnut : red, 0.8))
            ctx.setLineWidth(1.8)
            ctx.addPath(circle(50, 22, 7.5))
            ctx.strokePath()
            ctx.setStrokeColor(c(ink, 0.7))
            ctx.setLineWidth(0.9)
            ctx.move(to: CGPoint(x: 50, y: 17))
            ctx.addCurve(to: CGPoint(x: 30, y: -4), control1: CGPoint(x: 52, y: 6), control2: CGPoint(x: 38, y: 2))
            ctx.strokePath()
            let words = text ?? (luggage ? "TRAVEL" : "¥ 9.9")
            if luggage {
                RetroPrint.text(ctx, words, fonts: RetroPrint.condensed, size: 18, color: c(walnut), x: 50, baseline: 62, maxWidth: 78, tracking: 1)
                ctx.setStrokeColor(c(walnut, 0.5))
                ctx.setLineWidth(0.7)
                for (i, label) in ["FROM", "TO"].enumerated() {
                    let y = 90 + CGFloat(i) * 22
                    RetroPrint.text(ctx, label, fonts: RetroPrint.typewriter, size: 6, color: c(walnut), x: 14, baseline: y, align: -1)
                    ctx.move(to: CGPoint(x: 32, y: y + 1))
                    ctx.addLine(to: CGPoint(x: 86, y: y + 1))
                }
                ctx.strokePath()
            } else {
                RetroPrint.text(ctx, "PRICE", fonts: RetroPrint.typewriter, size: 7, color: c(ink, 0.8), x: 50, baseline: 56, tracking: 1)
                RetroPrint.text(ctx, words, fonts: RetroPrint.condensed, size: 24, color: c(red), x: 50, baseline: 92, maxWidth: 80)
                RetroPrint.text(ctx, number, fonts: RetroPrint.typewriter, size: 6, color: c(ink, 0.6), x: 50, baseline: h - 18)
            }
        case "ephemera.filmstrip":
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0.4 * px, height: -0.9 * px), blur: 2 * px, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            fill(ctx, CGPath(rect: CGRect(x: 2, y: 4, width: 96, height: h - 8), transform: nil), "#17110D")
            for i in 0..<3 {
                let frame = CGRect(x: 6 + CGFloat(i) * 31.3, y: 11, width: 28, height: h - 22)
                if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c(["#C98B4A", "#8A5A3A", "#B3743E"][i]), c(["#5A3A28", "#3A2A20", "#6A4A30"][i])] as CFArray, locations: [0, 1]) {
                    ctx.saveGState()
                    ctx.clip(to: frame)
                    ctx.drawLinearGradient(g, start: CGPoint(x: frame.minX, y: frame.minY), end: CGPoint(x: frame.maxX, y: frame.maxY), options: [])
                    ctx.restoreGState()
                }
            }
            ctx.setBlendMode(.destinationOut)
            ctx.setFillColor(c("#000000"))
            var x: CGFloat = 4
            while x < 96 {
                ctx.addPath(rounded(CGRect(x: x, y: 5.5, width: 2.6, height: 3.6), 0.6))
                ctx.addPath(rounded(CGRect(x: x, y: h - 9.1, width: 2.6, height: 3.6), 0.6))
                x += 5.2
            }
            ctx.fillPath()
            ctx.setBlendMode(.normal)
            RetroPrint.text(ctx, "NOCCHI ▸ 12A", fonts: RetroPrint.typewriter, size: 3.2, color: c("#E39B3A"), x: 20, baseline: h - 10.6, align: -1)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        case "ephemera.corner":
            let corner = CGMutablePath()
            corner.addLines(between: [CGPoint(x: 6, y: 6), CGPoint(x: 94, y: 6), CGPoint(x: 6, y: 94)])
            corner.closeSubpath()
            RetroPrint.paperShadow(ctx, shape: corner, px: px, fill: c("#1B1A18"))
            ctx.saveGState()
            ctx.addPath(corner)
            ctx.clip()
            if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#FFFFFF", 0), c("#FFFFFF", 0.22), c("#FFFFFF", 0)] as CFArray, locations: [0.3, 0.5, 0.7]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 20, y: 20), end: CGPoint(x: 60, y: 60), options: [])
            }
            ctx.restoreGState()
        case "ephemera.receipt":
            let slip = CGMutablePath()
            slip.move(to: CGPoint(x: 8, y: 4))
            slip.addLine(to: CGPoint(x: 92, y: 4))
            slip.addLine(to: CGPoint(x: 92, y: h - 8))
            var zx: CGFloat = 92
            var up = true
            while zx > 8 {
                zx -= 4
                slip.addLine(to: CGPoint(x: max(zx, 8), y: up ? h - 4 : h - 8))
                up.toggle()
            }
            slip.closeSubpath()
            RetroPrint.paperShadow(ctx, shape: slip, px: px, fill: c("#FBF8F0"))
            let lines = ["NOCCHI PHOTO LAB", "刘海冲印店", "- - - - - - - - - -", "冲印 × 1     ¥0", "胶卷 × 1     ¥0", "- - - - - - - - - -", "合计          ¥0", "", "谢谢光临", number] // i18n-ok：贴纸上印的字（图案的一部分）
            var y: CGFloat = 16
            for line in lines {
                if !line.isEmpty {
                    RetroPrint.text(ctx, line, fonts: ["Courier", "AmericanTypewriter"], size: 6.4, color: c(ink, 0.82), x: 50, baseline: y, maxWidth: 76)
                }
                y += 13.5
            }
        case "ephemera.matchbox":
            let label = CGRect(x: 4, y: 4, width: 92, height: h - 8)
            RetroPrint.paperShadow(ctx, shape: CGPath(rect: label, transform: nil), px: px, fill: c(red))
            ctx.setStrokeColor(c(cream))
            ctx.setLineWidth(1.6)
            ctx.stroke(label.insetBy(dx: 4, dy: 4))
            fill(ctx, circle(50, h / 2, 17), mustard)
            fill(ctx, RetroPrint.star(center: CGPoint(x: 50, y: h / 2), points: 5, outer: 12, inner: 5), red)
            RetroPrint.text(ctx, "NOCCHI", fonts: RetroPrint.condensed, size: 9, color: c(cream), x: 22, baseline: h / 2 + 3, maxWidth: 24)
            RetroPrint.text(ctx, "MATCHES", fonts: RetroPrint.condensed, size: 7, color: c(cream), x: 78, baseline: h / 2 + 3, maxWidth: 24)
            RetroPrint.speckle(ctx, rect: label, seed: seed, density: 1, alpha: 0.1, dark: false)
        case "ephemera.label":
            let shape = RetroPrint.scallopedRect(CGRect(x: 9, y: 9, width: 82, height: h - 18), radius: 3.2)
            RetroPrint.paperShadow(ctx, shape: shape, px: px, fill: c("#F6EEDB"))
            ctx.setStrokeColor(c(red, 0.85))
            ctx.setLineWidth(1.4)
            ctx.addPath(rounded(CGRect(x: 15, y: 15, width: 70, height: h - 30), 5))
            ctx.strokePath()
            ctx.setLineWidth(0.6)
            ctx.addPath(rounded(CGRect(x: 18, y: 18, width: 64, height: h - 36), 3.5))
            ctx.strokePath()
            RetroPrint.text(ctx, text ?? "No. 7", fonts: RetroPrint.serifBold, size: 16, color: c(ink), x: 50, baseline: h / 2 + 6, maxWidth: 58)
        default:
            break
        }
    }

    // MARK: - 胶带

    private static func drawTape(_ id: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat, _ seed: UInt64) {
        let top: CGFloat = 4
        let bottom = h - 4
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: 5, y: top))
        shape.addLine(to: CGPoint(x: 95, y: top))
        RetroPrint.tornEdge(shape, x: 95, top: top, bottom: bottom, depth: 2.4, seed: seed &+ 1, reverse: false)
        shape.addLine(to: CGPoint(x: 5, y: bottom))
        RetroPrint.tornEdge(shape, x: 5, top: top, bottom: bottom, depth: 2.4, seed: seed &+ 2, reverse: true)
        shape.closeSubpath()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: h)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.4 * px), blur: 1.2 * px, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.18))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.addPath(shape)
        ctx.clip()
        switch id {
        case "tape.kraft":
            fill(ctx, shape, "#C29B6C", 0.9)
            ctx.setStrokeColor(c(walnut, 0.12))
            ctx.setLineWidth(0.35)
            var rng = SeededRandom(seed: seed)
            for _ in 0..<60 {
                let x = CGFloat(rng.unit()) * 100
                let y = CGFloat(rng.unit()) * h
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + CGFloat(rng.range(2, 8)), y: y + CGFloat(rng.range(-0.6, 0.6))))
            }
            ctx.strokePath()
        case "tape.washi":
            fill(ctx, shape, "#EFE5D0", 0.78)
            RetroPrint.speckle(ctx, rect: bounds, seed: seed, density: 1.4, alpha: 0.1)
        case "tape.stripe":
            fill(ctx, shape, cream, 0.85)
            ctx.setFillColor(c(terracotta, 0.82))
            var x: CGFloat = -h
            while x < 110 {
                let stripe = CGMutablePath()
                stripe.addLines(between: [CGPoint(x: x, y: h), CGPoint(x: x + 4, y: h), CGPoint(x: x + 4 + h, y: 0), CGPoint(x: x + h, y: 0)])
                stripe.closeSubpath()
                ctx.addPath(stripe)
                x += 9
            }
            ctx.fillPath()
        case "tape.check":
            fill(ctx, shape, "#FBF4E2", 0.85)
            ctx.setFillColor(c(mustard, 0.38))
            var x: CGFloat = 0
            while x < 100 {
                ctx.fill(CGRect(x: x, y: 0, width: 3.5, height: h))
                x += 7
            }
            var y: CGFloat = 0
            while y < h {
                ctx.fill(CGRect(x: 0, y: y, width: 100, height: 3.5))
                y += 7
            }
        case "tape.dots":
            fill(ctx, shape, navy, 0.88)
            RetroPrint.halftone(ctx, rect: bounds, spacing: 6, radius: 1.2, color: c(cream, 0.9))
        case "tape.grid":
            fill(ctx, shape, "#DCE6EE", 0.85)
            ctx.setStrokeColor(c("#FFFFFF", 0.9))
            ctx.setLineWidth(0.5)
            var x: CGFloat = 0
            while x < 100 {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: h))
                x += 4
            }
            var y: CGFloat = 0
            while y < h {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: 100, y: y))
                y += 4
            }
            ctx.strokePath()
        default:
            fill(ctx, shape, cream, 0.8)
        }
        // 胶带的光泽
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#FFFFFF", 0.22), c("#FFFFFF", 0), c("#000000", 0.05)] as CFArray, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: bottom), options: [])
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    // MARK: - 标签

    private static func drawLabel(_ id: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat, _ seed: UInt64, _ inkHex: String, _ text: String?) {
        if id == "label.typed" {
            let slip = CGRect(x: 3, y: 3, width: 94, height: h - 6)
            RetroPrint.paperShadow(ctx, shape: CGPath(rect: slip, transform: nil), px: px, fill: c("#FBF7EC"))
            ctx.saveGState()
            ctx.clip(to: slip)
            RetroPrint.speckle(ctx, rect: slip, seed: seed, density: 1, alpha: 0.06)
            ctx.restoreGState()
            RetroPrint.text(ctx, text ?? "今天也很好", fonts: ["AmericanTypewriter", "Courier", "STSongti-SC-Regular"], size: 9, color: c(ink, 0.88), x: 50, baseline: h / 2 + 3, maxWidth: 86, tracking: 0.4) // i18n-ok：贴纸上印的字（图案的一部分）
            return
        }
        let tape = rounded(CGRect(x: 2, y: 3, width: 96, height: h - 6), 2.2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.3 * px, height: -0.8 * px), blur: 1.6 * px, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3))
        fill(ctx, tape, inkHex)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(tape)
        ctx.clip()
        // 塑料带的竖纹和高光
        ctx.setStrokeColor(c("#FFFFFF", 0.05))
        ctx.setLineWidth(0.4)
        var x: CGFloat = 2
        while x < 98 {
            ctx.move(to: CGPoint(x: x, y: 3))
            ctx.addLine(to: CGPoint(x: x, y: h - 3))
            x += 1.6
        }
        ctx.strokePath()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c("#FFFFFF", 0.22), c("#FFFFFF", 0), c("#000000", 0.18)] as CFArray, locations: [0, 0.45, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 3), end: CGPoint(x: 0, y: h - 3), options: [])
        }
        ctx.restoreGState()
        // 凸字：暗边、亮边、白色主体
        let words = (text ?? "NOCCHI").uppercased()
        let size: CGFloat = min(h * 0.55, 13)
        let baseline = h / 2 + size * 0.36
        RetroPrint.text(ctx, words, fonts: RetroPrint.condensed, size: size, color: c("#000000", 0.45), x: 50.4, baseline: baseline + 0.5, maxWidth: 88, tracking: 1.6)
        RetroPrint.text(ctx, words, fonts: RetroPrint.condensed, size: size, color: c("#FFFFFF", 0.95), x: 49.8, baseline: baseline - 0.25, maxWidth: 88, tracking: 1.6)
        RetroPrint.text(ctx, words, fonts: RetroPrint.condensed, size: size, color: c("#F1EEE8", 0.9), x: 50, baseline: baseline, maxWidth: 88, tracking: 1.6)
    }

    // MARK: - 表情（乙烯模切）

    private static func drawEmoji(_ character: String, _ ctx: CGContext, _ h: CGFloat, _ px: CGFloat) {
        // 先在离屏位图里画出表情；白边 = 把表情朝 16 个方向各偏一点叠起来，再整体染成白色。
        let pixels = max(16, Int(100 * px))
        guard !character.isEmpty, let glyph = emojiImage(character, pixels: pixels) else { return }
        let inset: CGFloat = 12
        let rect = CGRect(x: inset, y: inset, width: 100 - inset * 2, height: h - inset * 2)
        let border: CGFloat = 3.6
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5 * px, height: -1.1 * px), blur: 2.4 * px, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.32))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for i in 0..<16 {
            let a = CGFloat(i) * .pi / 8
            drawUpright(ctx, glyph, in: rect.offsetBy(dx: cos(a) * border, dy: sin(a) * border))
        }
        drawUpright(ctx, glyph, in: rect)
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(c("#FBF8F1"))
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: h))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
        drawUpright(ctx, glyph, in: rect)
    }

    /// 在 y 向下的上下文里正着画一张图。
    private static func drawUpright(_ ctx: CGContext, _ image: CGImage, in rect: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    private static func emojiImage(_ character: String, pixels: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let size = CGFloat(pixels) * 0.82
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, size, nil)
        let line = RetroPrint.line(character, font: font, color: RetroPrint.color("#000000"))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        ctx.textPosition = CGPoint(x: (CGFloat(pixels) - bounds.width) / 2 - bounds.minX, y: (CGFloat(pixels) - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, ctx)
        return ctx.makeImage()
    }
}
