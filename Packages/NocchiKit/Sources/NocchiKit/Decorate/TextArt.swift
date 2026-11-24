import CoreGraphics
import CoreText
import Foundation

/// 照片上任意位置的一段文字（装饰台里加的文字框）。坐标都是相纸宽度单位，原点左上。
public struct TextPlacement: Codable, Hashable, Identifiable, Sendable {
    public enum Style: String, Codable, CaseIterable, Identifiable, Sendable {
        /// 只有字。
        case plain
        /// 白色模切边（像贴纸一样）。
        case outline
        /// 衬一张纸标签。
        case label
        /// 柔和的投影。
        case shadow

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .plain: return String(localized: "无")
            case .outline: return String(localized: "白边")
            case .label: return String(localized: "纸标签")
            case .shadow: return String(localized: "投影")
            }
        }
    }

    public var id: UUID
    public var text: String
    /// 字体家族（或 PostScript 名）；没装的字体回落到题字的手写体。
    public var fontFamily: String
    /// 字号（相纸宽度单位）。
    public var size: Double
    /// 颜色（#RRGGBB）。
    public var color: String
    /// 中心点。
    public var x: Double
    public var y: Double
    /// 顺时针旋转角度（度）。
    public var rotation: Double
    /// 对齐：-1 左、0 居中、1 右（多行时）。
    public var alignment: Int
    public var bold: Bool
    public var italic: Bool
    public var style: Style
    /// 字距（字号的倍数）。
    public var tracking: Double

    public init(
        id: UUID = UUID(),
        text: String,
        fontFamily: String = "Baskerville",
        size: Double = 0.07,
        color: String = "#2B2A28",
        x: Double = 0.5,
        y: Double = 0.5,
        rotation: Double = 0,
        alignment: Int = 0,
        bold: Bool = false,
        italic: Bool = false,
        style: Style = .plain,
        tracking: Double = 0
    ) {
        self.id = id
        self.text = text
        self.fontFamily = fontFamily
        self.size = size
        self.color = color
        self.x = x
        self.y = y
        self.rotation = rotation
        self.alignment = alignment
        self.bold = bold
        self.italic = italic
        self.style = style
        self.tracking = tracking
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, fontFamily, size, color, x, y, rotation, alignment, bold, italic, style, tracking
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(.id, default: UUID())
        text = try c.decode(.text, default: "")
        fontFamily = try c.decode(.fontFamily, default: "Baskerville")
        size = try c.decode(.size, default: 0.07)
        color = try c.decode(.color, default: "#2B2A28")
        x = try c.decode(.x, default: 0.5)
        y = try c.decode(.y, default: 0.5)
        rotation = try c.decode(.rotation, default: 0)
        alignment = try c.decode(.alignment, default: 0)
        bold = try c.decode(.bold, default: false)
        italic = try c.decode(.italic, default: false)
        style = try c.decode(.style, default: Style.plain)
        tracking = try c.decode(.tracking, default: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(fontFamily, forKey: .fontFamily)
        try c.encode(size, forKey: .size)
        try c.encode(color, forKey: .color)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(rotation, forKey: .rotation)
        try c.encode(alignment, forKey: .alignment)
        try c.encode(bold, forKey: .bold)
        try c.encode(italic, forKey: .italic)
        try c.encode(style, forKey: .style)
        try c.encode(tracking, forKey: .tracking)
    }
}

/// 文字框的画法（Core Text）。屏幕上的装饰台和导出的成片用同一套，保证一模一样。
public enum TextArt {
    /// 排好的一段字。
    struct Layout {
        let lines: [CTLine]
        /// 白边样式：同样的字、只描边（Core Text 按属性决定描边还是填充，不看上下文的文字绘制模式）。
        let outlineLines: [CTLine]
        let widths: [CGFloat]
        let ascent: CGFloat
        let lineHeight: CGFloat
        let size: CGSize
        let font: CTFont
    }

    /// 文字框的外框（未旋转，像素，左上原点）：字的范围加上样式需要的边距。
    public static func frame(of text: TextPlacement, paperWidth: CGFloat) -> CGRect {
        let layout = makeLayout(text, paperWidth: paperWidth)
        let pad = padding(text, fontSize: CTFontGetSize(layout.font))
        let width = layout.size.width + pad.width * 2
        let height = layout.size.height + pad.height * 2
        return CGRect(x: CGFloat(text.x) * paperWidth - width / 2, y: CGFloat(text.y) * paperWidth - height / 2, width: width, height: height)
    }

    /// 画在相纸上（上下文已翻转成左上原点）。
    public static func draw(_ text: TextPlacement, in ctx: CGContext, paperWidth: CGFloat) {
        guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let layout = makeLayout(text, paperWidth: paperWidth)
        let center = CGPoint(x: CGFloat(text.x) * paperWidth, y: CGFloat(text.y) * paperWidth)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: CGFloat(text.rotation) * .pi / 180)
        drawBlock(text, layout: layout, in: ctx)
        ctx.restoreGState()
    }

    /// 单独渲染成透明图（装饰台上的可拖动文字框）。`scale` = 每个相纸宽度单位多少像素。
    public static func image(_ text: TextPlacement, paperWidth: CGFloat) -> CGImage? {
        guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let layout = makeLayout(text, paperWidth: paperWidth)
        let pad = padding(text, fontSize: CTFontGetSize(layout.font))
        let width = Int(ceil(layout.size.width + pad.width * 2))
        let height = Int(ceil(layout.size.height + pad.height * 2))
        guard width > 0, height > 0, width < 8192, height < 8192,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        drawBlock(text, layout: layout, in: ctx)
        return ctx.makeImage()
    }

    // MARK: - 排版

    static func font(for text: TextPlacement, size: CGFloat) -> CTFont {
        var base = FontBook.font([text.fontFamily, "BradleyHandITCTT-Bold", "Baskerville"], size: size)
        var traits: CTFontSymbolicTraits = []
        if text.bold { traits.insert(.traitBold) }
        if text.italic { traits.insert(.traitItalic) }
        if !traits.isEmpty, let styled = CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, traits) {
            base = styled
        }
        return base
    }

    static func makeLayout(_ text: TextPlacement, paperWidth: CGFloat) -> Layout {
        let fontSize = max(4, CGFloat(text.size) * paperWidth)
        let font = font(for: text, size: fontSize)
        let color = RetroPrint.color(text.color)
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        if text.tracking != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = CGFloat(text.tracking) * fontSize
        }
        var outlineAttributes = attributes
        outlineAttributes[NSAttributedString.Key(kCTStrokeWidthAttributeName as String)] = 28.0
        outlineAttributes[NSAttributedString.Key(kCTStrokeColorAttributeName as String)] = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let rawLines = text.text.components(separatedBy: "\n")
        var lines: [CTLine] = []
        var outlineLines: [CTLine] = []
        var widths: [CGFloat] = []
        for raw in rawLines {
            let string = raw.isEmpty ? " " : raw
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            lines.append(line)
            if text.style == .outline {
                outlineLines.append(CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: outlineAttributes)))
            }
            widths.append(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
        }
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let lineHeight = (ascent + descent) * 1.12
        let size = CGSize(width: max(widths.max() ?? 0, fontSize * 0.4), height: lineHeight * CGFloat(max(lines.count, 1)))
        return Layout(lines: lines, outlineLines: outlineLines, widths: widths, ascent: ascent, lineHeight: lineHeight, size: size, font: font)
    }

    static func padding(_ text: TextPlacement, fontSize: CGFloat) -> CGSize {
        switch text.style {
        case .plain: return CGSize(width: fontSize * 0.1, height: fontSize * 0.08)
        case .outline: return CGSize(width: fontSize * 0.22, height: fontSize * 0.2)
        case .label: return CGSize(width: fontSize * 0.55, height: fontSize * 0.32)
        case .shadow: return CGSize(width: fontSize * 0.3, height: fontSize * 0.34)
        }
    }

    /// 以 (0, 0) 为中心画整段字（上下文 y 向下）。
    static func drawBlock(_ text: TextPlacement, layout: Layout, in ctx: CGContext) {
        let fontSize = CTFontGetSize(layout.font)
        let block = CGRect(x: -layout.size.width / 2, y: -layout.size.height / 2, width: layout.size.width, height: layout.size.height)
        if text.style == .label {
            let pad = padding(text, fontSize: fontSize)
            let card = block.insetBy(dx: -pad.width, dy: -pad.height)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: fontSize * 0.03, height: fontSize * 0.06), blur: fontSize * 0.18, color: CGColor(srgbRed: 0.1, green: 0.07, blue: 0.04, alpha: 0.3))
            ctx.addPath(CGPath(roundedRect: card, cornerWidth: fontSize * 0.08, cornerHeight: fontSize * 0.08, transform: nil))
            ctx.setFillColor(RetroPrint.color("#F7F1E4"))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.addPath(CGPath(roundedRect: card.insetBy(dx: fontSize * 0.08, dy: fontSize * 0.08), cornerWidth: fontSize * 0.04, cornerHeight: fontSize * 0.04, transform: nil))
            ctx.setStrokeColor(RetroPrint.color("#B23A2A", 0.45))
            ctx.setLineWidth(max(0.6, fontSize * 0.02))
            ctx.strokePath()
        }
        if text.style == .outline {
            drawLines(layout.outlineLines, text: text, layout: layout, block: block, in: ctx) { ctx, line in
                ctx.setLineJoin(.round)
                ctx.setShadow(offset: CGSize(width: 0, height: fontSize * 0.03), blur: fontSize * 0.08, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
                CTLineDraw(line, ctx)
            }
        }
        drawLines(layout.lines, text: text, layout: layout, block: block, in: ctx) { ctx, line in
            if text.style == .shadow {
                ctx.setShadow(offset: CGSize(width: fontSize * 0.04, height: fontSize * 0.08), blur: fontSize * 0.22, color: CGColor(srgbRed: 0.08, green: 0.05, blue: 0.03, alpha: 0.45))
            }
            CTLineDraw(line, ctx)
        }
    }

    /// 逐行定位（对齐、基线），在每行的局部坐标里翻转成 Core Text 的坐标再画。
    private static func drawLines(_ lines: [CTLine], text: TextPlacement, layout: Layout, block: CGRect, in ctx: CGContext, draw: (CGContext, CTLine) -> Void) {
        for (index, line) in lines.enumerated() where index < layout.widths.count {
            let width = layout.widths[index]
            let x: CGFloat
            switch text.alignment {
            case ..<0: x = block.minX
            case 1...: x = block.maxX - width
            default: x = block.midX - width / 2
            }
            let baseline = block.minY + CGFloat(index) * layout.lineHeight + layout.ascent + (layout.lineHeight - layout.ascent - CTFontGetDescent(layout.font)) / 2
            ctx.saveGState()
            ctx.translateBy(x: x, y: baseline)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = .zero
            draw(ctx, line)
            ctx.restoreGState()
        }
    }
}
