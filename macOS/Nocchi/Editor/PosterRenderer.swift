import AppKit
import CoreText
import NocchiKit
import SwiftUI

/// 分享海报的背景（程序化或用现有纹理）。
enum PosterBackground: String, CaseIterable, Identifiable, Sendable {
    case linen
    case walnut
    case kraft
    case velvet
    case cork
    case seventies
    case sky
    case darkroom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linen: String(localized: "亚麻")
        case .walnut: String(localized: "胡桃木")
        case .kraft: String(localized: "牛皮纸")
        case .velvet: String(localized: "丝绒")
        case .cork: String(localized: "软木")
        case .seventies: String(localized: "70 年代")
        case .sky: String(localized: "晴空")
        case .darkroom: String(localized: "暗房红光")
        }
    }

    /// 检查器里的色块。
    var swatch: LinearGradient {
        let colors: [Color]
        switch self {
        case .linen: colors = [Color(hex: 0xEFE8DA), Color(hex: 0xE0D6C4)]
        case .walnut: colors = [Color(hex: 0x6A4630), Color(hex: 0x3A2618)]
        case .kraft: colors = [Color(hex: 0xC6A47A), Color(hex: 0xA9875C)]
        case .velvet: colors = [Color(hex: 0x9A4232), Color(hex: 0x5E2218)]
        case .cork: colors = [Color(hex: 0xC99D6E), Color(hex: 0xA97B4E)]
        case .seventies: colors = [Color(hex: 0xD9A441), Color(hex: 0xC4593B), Color(hex: 0x6B3A26)]
        case .sky: colors = [Color(hex: 0x8DB8D8), Color(hex: 0xE9F0F2)]
        case .darkroom: colors = [Color(hex: 0xB0352A), Color(hex: 0x2A0E0C)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    var isDark: Bool {
        switch self {
        case .walnut, .velvet, .darkroom: true
        default: false
        }
    }

    /// 用到的纹理（`Shared/Art.xcassets`）。
    var textureName: String? {
        switch self {
        case .walnut: "WoodTexture"
        case .velvet: "VelvetTexture"
        case .cork: "CorkTexture"
        case .linen: "PaperTexture"
        default: nil
        }
    }
}

/// 相片在海报上的摆法。
enum PosterArrangement: String, CaseIterable, Identifiable, Sendable {
    case centered
    case tilted
    case stacked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .centered: String(localized: "居中")
        case .tilted: String(localized: "微斜")
        case .stacked: String(localized: "两张叠放")
        }
    }
}

/// 主线程上取纹理（`NSImage(named:)`），交给后台渲染。
@MainActor
enum PosterTextures {
    static func load(for background: PosterBackground) -> CGImage? {
        guard let name = background.textureName, let image = NSImage(named: name) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

/// 1080×1350 的分享海报：背景 + 带真实阴影的相片 + 右下角一行小字。
enum PosterRenderer {
    static let size = CGSize(width: 1080, height: 1350)

    static func render(print: CGImage, background: PosterBackground, arrangement: PosterArrangement, signature: String?, texture: CGImage?) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.interpolationQuality = .high
        let canvas = CGRect(origin: .zero, size: size)
        drawBackground(ctx, canvas, background, texture)

        let aspect = CGFloat(print.width) / max(1, CGFloat(print.height))
        var width = canvas.width * 0.64
        var height = width / aspect
        if height > canvas.height * 0.72 {
            height = canvas.height * 0.72
            width = height * aspect
        }
        let printSize = CGSize(width: width, height: height)
        let center = CGPoint(x: canvas.midX, y: canvas.midY + 24)
        switch arrangement {
        case .centered:
            drawPrint(ctx, print, center: center, size: printSize, degrees: 0)
        case .tilted:
            drawPrint(ctx, print, center: center, size: printSize, degrees: 4)
        case .stacked:
            drawPrint(ctx, print, center: CGPoint(x: center.x + 34, y: center.y + 22), size: printSize, degrees: -7)
            drawPrint(ctx, print, center: CGPoint(x: center.x - 18, y: center.y - 12), size: printSize, degrees: 3)
        }

        if let signature {
            let ink = background.isDark ? CGColor(srgbRed: 0.96, green: 0.93, blue: 0.86, alpha: 0.82) : CGColor(srgbRed: 0.18, green: 0.16, blue: 0.14, alpha: 0.72)
            let font = FontBook.font(["AmericanTypewriter", "Courier"], size: 26)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
                NSAttributedString.Key(kCTKernAttributeName as String): 1.5
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: signature, attributes: attributes))
            let bounds = CTLineGetBoundsWithOptions(line, [])
            ctx.textPosition = CGPoint(x: canvas.maxX - 56 - bounds.width, y: 56)
            CTLineDraw(line, ctx)
        }
        return ctx.makeImage()
    }

    /// 一张相片：柔和投影 + 贴地的接触阴影（阴影偏移在基础坐标里，旋转后仍然落向右下）。
    private static func drawPrint(_ ctx: CGContext, _ image: CGImage, center: CGPoint, size: CGSize, degrees: CGFloat) {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: degrees * .pi / 180)
        ctx.setShadow(offset: CGSize(width: 10, height: -22), blur: 44, color: CGColor(gray: 0, alpha: 0.4))
        ctx.draw(image, in: rect)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: degrees * .pi / 180)
        ctx.setShadow(offset: CGSize(width: 1, height: -2), blur: 3, color: CGColor(gray: 0, alpha: 0.3))
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private static func drawBackground(_ ctx: CGContext, _ rect: CGRect, _ background: PosterBackground, _ texture: CGImage?) {
        func fill(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
            ctx.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1))
            ctx.fill(rect)
        }
        func tile(_ image: CGImage?, alpha: CGFloat, tileWidth: CGFloat = 540) {
            guard let image, image.width > 0 else { return }
            let tileHeight = tileWidth * CGFloat(image.height) / CGFloat(image.width)
            ctx.saveGState()
            ctx.setAlpha(alpha)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight), byTiling: true)
            ctx.restoreGState()
        }
        func gradient(_ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
            guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil) else { return }
            ctx.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        func vignette(_ strength: CGFloat) {
            guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: strength)] as CFArray, locations: [0.55, 1]) else { return }
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: hypot(rect.width, rect.height) / 2, options: [.drawsAfterEndLocation])
        }
        func threads(seed: UInt64, count: Int, alpha: CGFloat, dark: Bool) {
            var rng = SeededRandom(seed: seed)
            ctx.saveGState()
            ctx.setLineWidth(1.2)
            for index in 0..<count {
                let horizontal = index % 2 == 0
                let p = CGFloat(rng.unit())
                let start = CGFloat(rng.unit())
                let length = CGFloat(rng.range(40, 220))
                let a = alpha * CGFloat(rng.range(0.4, 1))
                ctx.setStrokeColor(dark ? CGColor(gray: 0.2, alpha: a) : CGColor(gray: 1, alpha: a))
                if horizontal {
                    let y = p * rect.height
                    let x = start * rect.width
                    ctx.move(to: CGPoint(x: x, y: y))
                    ctx.addLine(to: CGPoint(x: x + length, y: y))
                } else {
                    let x = p * rect.width
                    let y = start * rect.height
                    ctx.move(to: CGPoint(x: x, y: y))
                    ctx.addLine(to: CGPoint(x: x, y: y + length))
                }
                ctx.strokePath()
            }
            ctx.restoreGState()
        }

        switch background {
        case .linen:
            fill(0.92, 0.89, 0.83)
            tile(texture, alpha: 0.35)
            threads(seed: 11, count: 1400, alpha: 0.07, dark: true)
            threads(seed: 12, count: 900, alpha: 0.18, dark: false)
            vignette(0.12)
        case .walnut:
            fill(0.29, 0.19, 0.13)
            tile(texture, alpha: 0.9)
            ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
            ctx.fill(rect)
            vignette(0.45)
        case .kraft:
            fill(0.72, 0.58, 0.41)
            threads(seed: 21, count: 2200, alpha: 0.12, dark: true)
            threads(seed: 22, count: 900, alpha: 0.12, dark: false)
            vignette(0.2)
        case .velvet:
            gradient([CGColor(srgbRed: 0.6, green: 0.26, blue: 0.2, alpha: 1), CGColor(srgbRed: 0.37, green: 0.13, blue: 0.09, alpha: 1)], from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY))
            tile(texture, alpha: 0.75)
            vignette(0.5)
        case .cork:
            fill(0.72, 0.54, 0.36)
            tile(texture, alpha: 1)
            vignette(0.3)
        case .seventies:
            fill(0.95, 0.9, 0.8)
            let bands: [CGColor] = [
                CGColor(srgbRed: 0.85, green: 0.64, blue: 0.25, alpha: 1),
                CGColor(srgbRed: 0.88, green: 0.48, blue: 0.22, alpha: 1),
                CGColor(srgbRed: 0.77, green: 0.35, blue: 0.23, alpha: 1),
                CGColor(srgbRed: 0.42, green: 0.23, blue: 0.15, alpha: 1)
            ]
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.rotate(by: -0.38)
            let bandHeight: CGFloat = 92
            for (index, color) in bands.enumerated() {
                ctx.setFillColor(color)
                ctx.fill(CGRect(x: -rect.width, y: -bandHeight * 2 + CGFloat(index) * bandHeight - 120, width: rect.width * 2, height: bandHeight - 6))
            }
            ctx.restoreGState()
            vignette(0.08)
        case .sky:
            gradient([CGColor(srgbRed: 0.55, green: 0.72, blue: 0.85, alpha: 1), CGColor(srgbRed: 0.91, green: 0.94, blue: 0.95, alpha: 1)], from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY))
            if let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [CGColor(srgbRed: 1, green: 0.97, blue: 0.88, alpha: 0.7), CGColor(srgbRed: 1, green: 0.97, blue: 0.88, alpha: 0)] as CFArray, locations: nil) {
                let sun = CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.86)
                ctx.drawRadialGradient(glow, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: 360, options: [])
            }
        case .darkroom:
            if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [CGColor(srgbRed: 0.69, green: 0.21, blue: 0.16, alpha: 1), CGColor(srgbRed: 0.16, green: 0.05, blue: 0.05, alpha: 1)] as CFArray, locations: nil) {
                let c = CGPoint(x: rect.midX, y: rect.maxY * 0.62)
                ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: hypot(rect.width, rect.height) * 0.62, options: [.drawsAfterEndLocation])
            }
        }
    }
}
