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
    /// 相纸模板。
    public var template: PrintTemplate
    /// 题字字体。
    public var captionFont: CaptionFont
    /// 「#阳光 #咖啡」（nil = 不印）。
    public var tagLine: String?
    /// 「上海」（nil = 不印）。
    public var locationLine: String?
    /// 自动标签贴纸（kind ID），印在题字区右端。
    public var tagStickerIDs: [String]
    /// 用户贴的贴纸（按顺序从下往上）。
    public var stickers: [StickerPlacement]
    /// 照片上的文字框（叠在贴纸上面、笔画下面）。
    public var texts: [TextPlacement]
    /// 模板图样的随机种子（编号、星星位置……）。
    public var seed: UInt64

    public init(
        layout: PaperLayout,
        paper: PaperStyle,
        images: [CGImage],
        frameOffsets: [FrameOffset] = [],
        strokes: [InkStroke] = [],
        caption: String? = nil,
        dateText: String? = nil,
        widthPixels: Int,
        template: PrintTemplate = TemplateCatalog.classic,
        captionFont: CaptionFont = .handwriting,
        tagLine: String? = nil,
        locationLine: String? = nil,
        tagStickerIDs: [String] = [],
        stickers: [StickerPlacement] = [],
        texts: [TextPlacement] = [],
        seed: UInt64 = 0
    ) {
        self.layout = layout
        self.paper = paper
        self.images = images
        self.frameOffsets = frameOffsets
        self.strokes = strokes
        self.caption = caption
        self.dateText = dateText
        self.widthPixels = widthPixels
        self.template = template
        self.captionFont = captionFont
        self.tagLine = tagLine
        self.locationLine = locationLine
        self.tagStickerIDs = tagStickerIDs
        self.stickers = stickers
        self.texts = texts
        self.seed = seed
    }

    /// 从照片记录生成：套用模板相纸、题字字体、标签 / 地点、自动标签贴纸、贴纸、笔画。
    /// - stockPaper：胶卷自带的相纸（模板没有自带相纸时用它）。
    public init(record: PhotoRecord, stockPaper: PaperStyle, images: [CGImage], widthPixels: Int) {
        let template = TemplateCatalog.resolve(id: record.templateID, format: record.format)
        var stickerIDs: [String] = []
        if record.showsTagStickers {
            for tag in record.tags {
                guard let id = StickerCatalog.kindID(forTag: tag), !stickerIDs.contains(id) else { continue }
                stickerIDs.append(id)
                if stickerIDs.count == 2 { break }
            }
        }
        self.init(
            layout: record.layout,
            paper: template.resolvedPaper(stockPaper: stockPaper),
            images: images,
            frameOffsets: record.frameOffsets,
            strokes: record.strokes,
            caption: record.caption,
            dateText: record.showsDate ? record.dateText : nil,
            widthPixels: widthPixels,
            template: template,
            captionFont: record.captionFont,
            tagLine: record.tagLine,
            locationLine: record.locationLine,
            tagStickerIDs: stickerIDs,
            stickers: record.stickers,
            texts: record.texts,
            seed: record.seed
        )
    }

    /// 成片的像素尺寸。
    public var pixelSize: CGSize {
        let width = CGFloat(max(64, widthPixels))
        return CGSize(width: width, height: (width / layout.aspect).rounded())
    }
}

/// 用 Core Graphics 把底片、相纸模板、题字、贴纸和涂鸦合成一张「带白边的成片」。
///
/// 分成两层：`renderBase`（照片下面：纸、模板底纹）和 `renderOverlay`（照片上面：窗口阴影、
/// 模板图样、题字、贴纸、涂鸦）。屏幕上的 `PrintSurface` 用这两层夹住显影中的照片，
/// 所以屏幕上看到的就是导出的样子。
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

    // MARK: - 合成

    /// 完整成片 = renderBase + 照片 + renderOverlay。
    public static func render(_ spec: PrintSpec) -> CGImage? {
        guard let ctx = makeContext(spec) else { return nil }
        let size = spec.pixelSize
        drawBase(ctx, spec, size)
        drawPhotos(ctx, spec, size)
        drawOverlay(ctx, spec, size, includeStickers: true, includeStrokes: true)
        return ctx.makeImage()
    }

    /// 照片下面的一切：相纸、模板底纹（相纸外透明）。
    public static func renderBase(_ spec: PrintSpec) -> CGImage? {
        guard let ctx = makeContext(spec) else { return nil }
        drawBase(ctx, spec, spec.pixelSize)
        return ctx.makeImage()
    }

    /// 照片上面的一切：窗口内凹阴影与发丝边、模板前景图样、题字 / 日期 / 地点 / 标签、
    /// 标签贴纸、贴纸与文字框（`includeStickers`）、笔画（其余透明）。
    public static func renderOverlay(_ spec: PrintSpec, includeStickers: Bool = true, includeStrokes: Bool = true) -> CGImage? {
        guard let ctx = makeContext(spec) else { return nil }
        drawOverlay(ctx, spec, spec.pixelSize, includeStickers: includeStickers, includeStrokes: includeStrokes)
        return ctx.makeImage()
    }

    /// 第 index 个图像窗口的形状（像素，左上原点，相纸宽 width）。
    public static func windowPath(layout: PaperLayout, template: PrintTemplate, index: Int, width: CGFloat) -> CGPath {
        TemplateArt.window(template, layout: layout, index: index, width: width)
    }

    /// 相纸外轮廓（像素，左上原点）。`evenOdd` 为 true 时用 even-odd 规则。
    /// 邮票的齿孔不在轮廓里：`renderBase` 直接在纸上挖孔。
    public static func paperOutline(layout: PaperLayout, template: PrintTemplate, size: CGSize) -> (path: CGPath, evenOdd: Bool) {
        TemplateArt.outline(template, layout: layout, size: size)
    }

    /// 左上原点、透明底的位图上下文。
    static func makeContext(_ spec: PrintSpec) -> CGContext? {
        let size = spec.pixelSize
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
        ctx.setShouldAntialias(true)
        // 翻转成左上角原点，和 SwiftUI 一致。
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    static func drawBase(_ ctx: CGContext, _ spec: PrintSpec, _ size: CGSize) {
        let outline = TemplateArt.outline(spec.template, layout: spec.layout, size: size)
        ctx.saveGState()
        ctx.addPath(outline.path)
        ctx.clip(using: outline.evenOdd ? .evenOdd : .winding)
        TemplateArt.drawBase(ctx, spec: spec, size: size)
        ctx.restoreGState()
    }

    static func drawPhotos(_ ctx: CGContext, _ spec: PrintSpec, _ size: CGSize) {
        let layout = spec.layout
        for (index, window) in layout.windows.enumerated() where index < spec.images.count {
            let rect = layout.scaled(window, toWidth: size.width)
            let image = spec.images[index]
            let offset = index < spec.frameOffsets.count ? spec.frameOffsets[index] : .zero
            ctx.saveGState()
            ctx.addPath(windowPath(layout: layout, template: spec.template, index: index, width: size.width))
            ctx.clip()
            var target = aspectFill(CGSize(width: image.width, height: image.height), into: rect)
            target = target.offsetBy(dx: CGFloat(offset.dx) * rect.width, dy: CGFloat(offset.dy) * rect.height)
            drawImage(ctx, image, in: target)
            ctx.restoreGState()
        }
    }

    static func drawOverlay(_ ctx: CGContext, _ spec: PrintSpec, _ size: CGSize, includeStickers: Bool, includeStrokes: Bool) {
        let layout = spec.layout
        let width = size.width
        let lightHairline = spec.template.isDarkPaper
        // 窗口：内凹阴影 + 发丝边
        for (index, window) in layout.windows.enumerated() {
            let rect = layout.scaled(window, toWidth: width)
            switch spec.template.windowShape {
            case .rect:
                ctx.saveGState()
                ctx.clip(to: rect)
                drawRecess(ctx, rect: rect)
                ctx.restoreGState()
                ctx.setStrokeColor(lightHairline ? CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.16) : CGColor(srgbRed: 0, green: 0, blue: 0, alpha: spec.paper.isDark ? 0.45 : 0.22))
                ctx.setLineWidth(max(1, rect.width * 0.0035))
                ctx.stroke(rect.insetBy(dx: max(0.5, rect.width * 0.00175), dy: max(0.5, rect.width * 0.00175)))
            case .heart:
                let path = windowPath(layout: layout, template: spec.template, index: index, width: width)
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                ctx.addPath(path)
                ctx.setLineWidth(PrintGeometry.recessDepth(windowWidth: rect.width) * 2)
                ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.18))
                ctx.strokePath()
                ctx.restoreGState()
            }
        }

        TemplateArt.drawForeground(ctx, spec: spec, size: size)
        drawCaptionBlock(ctx, spec, size)
        if includeStickers {
            for sticker in spec.stickers {
                StickerArt.draw(sticker, in: ctx, paperWidth: width)
            }
            for text in spec.texts {
                TextArt.draw(text, in: ctx, paperWidth: width)
            }
        }
        if includeStrokes {
            drawStrokes(spec.strokes, in: ctx, paperWidth: width, defaultInk: spec.paper.inkRGB)
        }
    }

    // MARK: - 题字区

    /// 题字字体（带中文回落）。
    public static func captionCTFont(_ style: CaptionFont, size: CGFloat) -> CTFont {
        let primary: String
        let cascade: [String]
        switch style {
        case .handwriting:
            primary = captionFontName
            cascade = ["Kaiti SC", "STKaiti", "HanziPen SC", "Songti SC"]
        case .typewriter:
            primary = "AmericanTypewriter"
            cascade = ["STFangsong", "Songti SC"]
        case .serif:
            primary = "Baskerville"
            cascade = ["Songti SC", "STSong"]
        }
        // 后备字体只用装了的（楷体、翩翩体、仿宋多半是「可下载字体」，没下载时不能引用，见 FontBook）。
        let fallbacks = FontBook.installedFamilies(cascade).map {
            CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: $0] as CFDictionary)
        }
        var attributes: [CFString: Any] = [
            kCTFontNameAttribute: FontBook.isInstalled(primary) ? primary : "Helvetica"
        ]
        if !fallbacks.isEmpty {
            attributes[kCTFontCascadeListAttribute] = fallbacks
        }
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    static func drawCaptionBlock(_ ctx: CGContext, _ spec: PrintSpec, _ size: CGSize) {
        let layout = spec.layout
        let width = size.width
        let area = TemplateArt.captionArea(spec, width: width)
        guard area.width > 4, area.height > 4 else { return }
        let ink = spec.paper.inkRGB
        let s = width / layout.paperSize.width
        let written = spec.caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (written?.isEmpty == false ? written : nil) ?? TemplateArt.defaultCaption(spec.template)
        let date = spec.template.style == .datebook ? nil : spec.dateText
        var details: [String] = []
        if let location = spec.locationLine { details.append("「\(location)」") }
        if let tags = spec.tagLine { details.append(tags) }

        // 自动标签贴纸：题字区右端一到两枚小贴纸。
        var reserve: CGFloat = 0
        let stickerKinds = spec.tagStickerIDs.compactMap { StickerCatalog.kind(id: $0) }
        if !stickerKinds.isEmpty, area.height > 8 * s {
            let side = min(area.height * 0.92, area.width * 0.22)
            for (i, kind) in stickerKinds.enumerated() {
                let w = side * CGFloat(min(kind.aspect, 1.4))
                let h = w / CGFloat(max(kind.aspect, 0.05))
                let x = area.maxX - w / 2 - CGFloat(i) * side * 0.72
                let y = area.midY + (i == 0 ? 0 : -side * 0.08)
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: (i == 0 ? -7 : 6) * .pi / 180)
                StickerArt.draw(kind, in: ctx, rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), tint: nil, text: nil, seed: spec.seed &+ UInt64(i))
                ctx.restoreGState()
            }
            reserve = side * (0.72 * CGFloat(stickerKinds.count - 1) + 1) + area.width * 0.02
        }

        let captionSize = captionFontSize(paperWidth: width, layout: layout)
        let dateSize = dateFontSize(paperWidth: width, layout: layout)
        let roomy = area.height > 12 * s
        if details.isEmpty || !roomy {
            // 经典：居中的题字 + 日期。
            let centerX = area.minX + (area.width - reserve) / 2
            let maxWidth = area.width - reserve
            if let caption {
                let baseline = date == nil ? area.midY + captionSize * 0.35 : area.minY + area.height * 0.5
                drawText(ctx, caption, font: captionCTFont(spec.captionFont, size: captionSize), color: ink, x: centerX, baseline: baseline, maxWidth: maxWidth, alpha: 0.88)
            }
            if let date {
                let baseline = caption != nil ? area.minY + area.height * 0.86 : area.midY + dateSize * 0.35
                drawText(ctx, date, fontName: dateFontName, size: dateSize, color: ink, centerX: centerX, baselineY: baseline, maxWidth: maxWidth, alpha: 0.6, tracking: dateSize * 0.08)
            }
            if !details.isEmpty, caption == nil, date == nil {
                drawText(ctx, details.joined(separator: "  "), font: captionCTFont(.typewriter, size: dateSize), color: ink, x: centerX, baseline: area.midY + dateSize * 0.35, maxWidth: maxWidth, alpha: 0.7)
            }
            return
        }

        // 手帐式：题字靠左，下面一行地点与标签，日期在最下面。
        let left = area.minX + area.width * 0.03
        let maxWidth = area.width * 0.94 - reserve
        let small = dateSize * 0.92
        if let caption {
            drawText(ctx, caption, font: captionCTFont(spec.captionFont, size: captionSize * 0.86), color: ink, x: left, baseline: area.minY + area.height * 0.4, maxWidth: maxWidth, alpha: 0.88, align: -1)
        }
        drawText(ctx, details.joined(separator: "  "), font: captionCTFont(.typewriter, size: small), color: ink, x: left, baseline: area.minY + area.height * (caption == nil ? 0.45 : 0.68), maxWidth: maxWidth, alpha: 0.72, align: -1)
        if let date {
            drawText(ctx, date, font: captionCTFont(.typewriter, size: small * 0.9), color: ink, x: left, baseline: area.minY + area.height * 0.93, maxWidth: maxWidth, alpha: 0.5, align: -1, tracking: small * 0.06)
        }
    }

    /// 画一行字（y 向下的上下文）：align 0 居中、-1 左对齐、1 右对齐；太长时缩小字号。
    static func drawText(_ ctx: CGContext, _ text: String, font: CTFont, color: RGB, x: CGFloat, baseline: CGFloat, maxWidth: CGFloat, alpha: CGFloat = 1, align: Int = 0, tracking: CGFloat = 0) {
        guard !text.isEmpty else { return }
        var current = font
        var line: CTLine
        var bounds: CGRect
        repeat {
            var attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): current,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): cgColor(color, alpha: alpha)
            ]
            if tracking != 0 {
                attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = tracking * CTFontGetSize(current) / max(CTFontGetSize(font), 0.001)
            }
            line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            bounds = CTLineGetBoundsWithOptions(line, [])
            if bounds.width <= maxWidth || CTFontGetSize(current) < 4 { break }
            current = CTFontCreateCopyWithAttributes(current, CTFontGetSize(current) * 0.92, nil, nil)
        } while true
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
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: - 笔画

    /// 按 `InkTool` 画笔画（成片与装饰台共用）。坐标以相纸宽度为单位，paperWidth 是像素宽度。
    public static func drawStrokes(_ strokes: [InkStroke], in ctx: CGContext, paperWidth: CGFloat, defaultInk: RGB) {
        for (index, stroke) in strokes.enumerated() {
            let color = RGB(hex: stroke.color) ?? defaultInk
            let points = stroke.points.map { CGPoint(x: CGFloat($0.x) * paperWidth, y: CGFloat($0.y) * paperWidth) }
            let widths = stroke.points.map { CGFloat($0.w * stroke.tool.widthScale) * paperWidth }
            guard !points.isEmpty else { continue }
            ctx.saveGState()
            ctx.setAlpha(CGFloat(stroke.tool.opacity))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setStrokeColor(cgColor(color))
            ctx.setFillColor(cgColor(color))
            switch stroke.tool {
            case .pen, .paint:
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                strokeSegments(ctx, points, widths, scale: 1)
                if stroke.tool == .paint {
                    // 漆笔的一点光泽
                    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32))
                    ctx.translateBy(x: -(widths.first ?? 1) * 0.12, y: -(widths.first ?? 1) * 0.12)
                    strokeSegments(ctx, points, widths, scale: 0.28)
                }
            case .marker:
                ctx.setLineCap(.square)
                ctx.setLineJoin(.bevel)
                strokeSegments(ctx, points, widths, scale: 1)
            case .grease:
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                var rng = SeededRandom(seed: UInt64(index + 1) &* 0x9E37_79B9)
                for _ in 0..<3 {
                    let jitter = (widths.first ?? 1) * 0.22
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(rng.signed()) * jitter, y: CGFloat(rng.signed()) * jitter)
                    ctx.setAlpha(0.6)
                    strokeSegments(ctx, points, widths, scale: 0.55)
                    ctx.restoreGState()
                }
                // 蜡笔的干涩：沿笔画擦掉一些小点
                ctx.setBlendMode(.destinationOut)
                for (i, p) in points.enumerated() where i % 2 == 0 {
                    let w = widths[i]
                    for _ in 0..<2 {
                        let r = w * CGFloat(rng.range(0.06, 0.14))
                        let q = CGPoint(x: p.x + CGFloat(rng.signed()) * w * 0.4, y: p.y + CGFloat(rng.signed()) * w * 0.4)
                        ctx.fillEllipse(in: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2))
                    }
                }
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
    }

    private static func strokeSegments(_ ctx: CGContext, _ points: [CGPoint], _ widths: [CGFloat], scale: CGFloat) {
        if points.count == 1, let p = points.first {
            let r = widths[0] * scale / 2
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            return
        }
        for i in 1..<points.count {
            ctx.setLineWidth(max(0.5, (widths[i - 1] + widths[i]) / 2 * scale))
            ctx.move(to: points[i - 1])
            ctx.addLine(to: points[i])
            ctx.strokePath()
        }
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
            let font = FontBook.font([fontName], size: fontSize)
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
