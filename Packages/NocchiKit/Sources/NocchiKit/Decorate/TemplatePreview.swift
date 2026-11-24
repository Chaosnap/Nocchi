import CoreGraphics
import Foundation

/// 模板预览：用暖灰占位格（中间一个柔和的半身剪影）合成一张相纸。
///
/// 大头贴机的「选相框」和设置里的默认模板都用它。和成片走同一套 `PhotoComposer`，看到的就是印出来的样子。
public enum TemplatePreview {
    /// 一格占位画面（按窗口比例）：暖灰渐变（黑白卷用中性灰）、左上角一团暖光、中间一个柔和的半身剪影、
    /// 极细的颗粒和暗角。`index` 让四格略有不同，像连拍时人在动。
    public static func placeholder(aspect: CGFloat, pixelWidth: Int, monochrome: Bool, index: Int) -> CGImage? {
        let width = max(16, pixelWidth)
        let height = max(16, Int((CGFloat(width) / max(aspect, 0.1)).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        let w = CGFloat(width)
        let h = CGFloat(height)
        let unit = min(w, h)
        let step = index % 4
        let lift = CGFloat(step) * 0.012

        // 1. 背景：上亮下暗（CGContext 原点在左下）。
        let top: [CGFloat] = monochrome ? [0.67, 0.67, 0.67] : [0.69, 0.65, 0.60]
        let bottom: [CGFloat] = monochrome ? [0.50, 0.50, 0.50] : [0.53, 0.49, 0.45]
        let background = [
            CGColor(srgbRed: top[0] + lift, green: top[1] + lift, blue: top[2] + lift, alpha: 1),
            CGColor(srgbRed: bottom[0] + lift, green: bottom[1] + lift, blue: bottom[2] + lift, alpha: 1)
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: background, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: .zero, options: [])
        }

        // 2. 左上角的暖光（和全局光源一致）。
        let glow = [
            CGColor(srgbRed: 1, green: monochrome ? 1 : 0.96, blue: monochrome ? 1 : 0.88, alpha: 0.24),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
            let center = CGPoint(x: w * 0.22, y: h * 0.86)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: max(w, h) * 0.75, options: [])
        }

        // 3. 半身剪影：头、脖子、肩膀，用同色阴影把边缘晕开。
        let shifts: [CGFloat] = [-0.05, 0.045, -0.02, 0.06]
        let cx = w * (0.5 + shifts[step])
        let headRadius = unit * 0.165
        let headCenter = CGPoint(x: cx, y: h * 0.58)
        let figure = monochrome
            ? CGColor(srgbRed: 0.36, green: 0.36, blue: 0.36, alpha: 0.62)
            : CGColor(srgbRed: 0.39, green: 0.35, blue: 0.32, alpha: 0.6)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: unit * 0.05, color: figure)
        ctx.setFillColor(figure)
        let shoulders = CGRect(x: cx - unit * 0.5, y: -h * 0.1, width: unit, height: h * 0.46)
        ctx.addEllipse(in: shoulders)
        let neck = CGRect(x: cx - headRadius * 0.36, y: shoulders.maxY - h * 0.06, width: headRadius * 0.72, height: headCenter.y - shoulders.maxY + h * 0.06)
        ctx.addRect(neck)
        ctx.addEllipse(in: CGRect(
            x: headCenter.x - headRadius * 0.86,
            y: headCenter.y - headRadius * 1.05,
            width: headRadius * 1.72,
            height: headRadius * 2.1
        ))
        ctx.fillPath()
        ctx.restoreGState()

        // 4. 极细颗粒（确定性的，同一格每次一样）。
        var random = SeededRandom(seed: 0xB007_0000 &+ UInt64(step))
        let dots = min(6000, width * height / 110)
        for _ in 0..<dots {
            let light = random.unit() > 0.5
            ctx.setFillColor(CGColor(srgbRed: light ? 1 : 0, green: light ? 1 : 0, blue: light ? 1 : 0, alpha: 0.05))
            ctx.fill(CGRect(x: random.unit() * Double(w), y: random.unit() * Double(h), width: 1, height: 1))
        }

        // 5. 暗角。
        let vignette = [
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.2)
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: vignette, locations: [0.55, 1]) {
            let center = CGPoint(x: w / 2, y: h / 2)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: (w * w + h * h).squareRoot() / 2, options: [.drawsAfterEndLocation])
        }
        return ctx.makeImage()
    }

    /// 合成一张模板预览（可以在后台线程调用）。`widthPixels` 是相纸的像素宽度。
    /// 模板不适用于这个规格时用这个规格的默认模板（和成片一致）。
    public static func render(
        template: PrintTemplate,
        format: FilmFormat,
        stock: FilmStock,
        caption: String? = nil,
        captionFont: CaptionFont = .handwriting,
        showsDate: Bool = true,
        date: Date = Date(),
        widthPixels: Int
    ) -> CGImage? {
        let layout = format.layout
        let body: CameraBody = format.isBooth ? .photoBooth : .instant
        var record = PhotoRecord(
            createdAt: date,
            source: format.isBooth ? .booth : .screen,
            body: body,
            stock: stock,
            seed: 20_261_124,
            showsDate: showsDate
        )
        record.format = format
        record.templateID = TemplateCatalog.resolve(id: template.id, format: format).id
        record.caption = caption
        record.captionFont = captionFont
        let windowWidth = layout.windows.first?.width ?? layout.paperSize.width
        let framePixels = max(32, Int(CGFloat(widthPixels) * windowWidth / layout.paperSize.width))
        let images = (0..<format.frameCount).compactMap { index in
            placeholder(aspect: layout.windowAspect, pixelWidth: framePixels, monochrome: stock.isMonochrome, index: index)
        }
        guard images.count == format.frameCount else { return nil }
        return PhotoComposer.render(PrintSpec(record: record, stockPaper: stock.paper, images: images, widthPixels: widthPixels))
    }
}

public extension TemplateCatalog {
    /// 大头贴机的默认相框。
    static let defaultBoothID = "booth-classic"

    /// 大头贴机「选相框」里的顺序：先是大头贴主题（老照相亭、黑白、情人节……），再是其余适用于这个规格的模板。
    static func boothTemplates(for format: FilmFormat) -> [PrintTemplate] {
        let usable = templates(for: format)
        let themed = usable.filter { $0.id.hasPrefix("booth-") }
        let rest = usable.filter { !$0.id.hasPrefix("booth-") }
        return themed + rest
    }
}

public extension FilmCatalog {
    /// 照相亭彩色卷（白光闪灯）。
    static let boothColorID = "booth-flash-400"
    /// 照相亭黑白卷。
    static let boothMonoID = "booth-silver-400"

    /// 大头贴机这一条用哪卷胶卷。
    ///
    /// 黑白：装着黑白卷就用它，否则用照相亭黑白 400。
    /// 彩色：装着自己挑的彩色卷就用它（默认胶卷不算），否则用照相亭闪光 400。
    static func boothStockID(monochrome: Bool, loaded: FilmStock) -> String {
        if monochrome {
            return loaded.isMonochrome ? loaded.id : boothMonoID
        }
        if loaded.isMonochrome || loaded.id == defaultStock.id {
            return boothColorID
        }
        return loaded.id
    }
}
