import CoreGraphics
import Foundation

/// 照片来源。
public enum PhotoSource: String, Codable, Sendable {
    /// Nocchi 自己的屏幕快门（框选截图）。
    case screen
    /// 接管的系统截图（⇧⌘3 / ⇧⌘4）。
    case systemScreenshot
    /// 前置摄像头自拍。
    case selfie
    /// 大头贴机四连拍。
    case booth
    /// iPhone 相机。
    case camera
    /// 从相册冲印。
    case library
}

/// 手写笔画上的一个点。x、y、w 都以相纸宽度为单位（x ∈ 0…1，y ∈ 0…1/aspect）。
public struct InkPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double

    public init(x: Double, y: Double, w: Double) {
        self.x = x
        self.y = y
        self.w = w
    }
}

/// 一笔手写 / 涂鸦。
public struct InkStroke: Codable, Hashable, Sendable {
    public var points: [InkPoint]
    public var color: String
    /// 用哪支笔画的（旧记录没有这个字段，按钢笔处理）。
    public var tool: InkTool

    public init(points: [InkPoint] = [], color: String, tool: InkTool = .pen) {
        self.points = points
        self.color = color
        self.tool = tool
    }

    /// 根据压感（0…1）计算笔画宽度（相纸宽度单位）。
    public static func width(pressure: Double) -> Double {
        0.0035 + 0.0095 * min(max(pressure, 0), 1)
    }

    /// 根据手指移动速度（点 / 秒）计算笔画宽度：越快越细，像马克笔。
    public static func width(speed: Double) -> Double {
        let k = min(max(speed / 1400, 0), 1)
        return 0.011 - 0.006 * k
    }

    private enum CodingKeys: String, CodingKey { case points, color, tool }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        points = try c.decode(.points, default: [])
        color = try c.decode(.color, default: "#2B2A28")
        tool = try c.decode(.tool, default: InkTool.pen)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(points, forKey: .points)
        try c.encode(color, forKey: .color)
        try c.encode(tool, forKey: .tool)
    }
}

/// 一帧画面相对图像窗口的错位（大头贴机的轻微错位）。
public struct FrameOffset: Codable, Hashable, Sendable {
    public var dx: Double
    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public static let zero = FrameOffset(dx: 0, dy: 0)
}

/// 照片在桌面上的位置。
public struct DeskPlacement: Codable, Hashable, Sendable {
    public enum Layer: String, Codable, Sendable {
        /// 浮在所有窗口上面。
        case floating
        /// 贴在桌面层（在其他窗口后面）。
        case desktop
    }

    /// Mac：窗口原点（全局屏幕坐标）；iPhone：照片中心（桌面坐标）。
    public var x: Double
    public var y: Double
    /// 倾斜角度（度）。
    public var rotation: Double
    public var layer: Layer

    public init(x: Double, y: Double, rotation: Double, layer: Layer = .floating) {
        self.x = x
        self.y = y
        self.rotation = rotation
        self.layer = layer
    }
}

/// 一张照片的全部信息（底片文件、手写、贴纸、模板、色块、位置……）。
///
/// 装饰（贴纸、涂鸦、模板、题字字体、地点、标签、拍摄时间）全部以数据保存，
/// 成片随时可以用 `PhotoComposer` 从底片重新合成——装饰是「非破坏性」的。
public struct PhotoRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var source: PhotoSource
    public var body: CameraBody
    public var stockID: String
    public var stockName: String
    public var format: FilmFormat
    public var seed: UInt64
    /// 冲印好的底片（每格一张），相对照片库 negatives 目录。
    public var negatives: [String]
    public var frameOffsets: [FrameOffset]
    /// 白边手写与装饰台里的涂鸦（坐标见 `InkPoint`）。
    public var strokes: [InkStroke]
    /// 打字的题字 / 心情（白边上的一行字）。
    public var caption: String?
    /// 是否在白边上印日期。
    public var showsDate: Bool
    public var blotches: [Blotch]
    public var developed: Bool
    /// 带白边的成片，相对照片库 prints 目录。
    public var printFile: String?
    /// 在桌面上的位置；nil 表示只在相册里。
    public var desk: DeskPlacement?
    /// 撕开后的另一半。
    public var tornFrom: UUID?

    // MARK: 装饰（v0.2 新增，旧记录解码时取默认值）

    /// 用户改过的拍摄时间（nil = 用 `createdAt`）。日期题字、日历都按 `displayDate`。
    public var takenAt: Date?
    /// 相纸模板（nil = 这个画幅的默认模板，见 `TemplateCatalog.defaultID(for:)`）。
    public var templateID: String?
    /// 题字字体。
    public var captionFont: CaptionFont
    /// 地点（「上海」）。
    public var location: String?
    /// 标签，不带「#」（「阳光」「咖啡」）。
    public var tags: [String]
    /// 贴纸（按数组顺序从下往上叠）。
    public var stickers: [StickerPlacement]
    /// 白边上是否印标签。
    public var showsTags: Bool
    /// 白边上是否印地点。
    public var showsLocation: Bool
    /// 是否给认识的标签自动配一枚小贴纸（「阳光」→ 复古太阳徽章）。
    public var showsTagStickers: Bool
    /// 最后一次在装饰台保存的时间。
    public var editedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: PhotoSource,
        body: CameraBody,
        stock: FilmStock,
        seed: UInt64,
        negatives: [String] = [],
        frameOffsets: [FrameOffset] = [],
        strokes: [InkStroke] = [],
        caption: String? = nil,
        showsDate: Bool = true,
        blotches: [Blotch] = [],
        developed: Bool = false,
        printFile: String? = nil,
        desk: DeskPlacement? = nil,
        tornFrom: UUID? = nil,
        takenAt: Date? = nil,
        templateID: String? = nil,
        captionFont: CaptionFont = .handwriting,
        location: String? = nil,
        tags: [String] = [],
        stickers: [StickerPlacement] = [],
        showsTags: Bool = true,
        showsLocation: Bool = true,
        showsTagStickers: Bool = true,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.body = body
        self.stockID = stock.id
        self.stockName = stock.name
        self.format = body.format
        self.seed = seed
        self.negatives = negatives
        self.frameOffsets = frameOffsets
        self.strokes = strokes
        self.caption = caption
        self.showsDate = showsDate
        self.blotches = blotches
        self.developed = developed
        self.printFile = printFile
        self.desk = desk
        self.tornFrom = tornFrom
        self.takenAt = takenAt
        self.templateID = templateID
        self.captionFont = captionFont
        self.location = location
        self.tags = tags
        self.stickers = stickers
        self.showsTags = showsTags
        self.showsLocation = showsLocation
        self.showsTagStickers = showsTagStickers
        self.editedAt = editedAt
    }

    // MARK: Codable（新字段缺省时回落到默认值，旧照片库照常读取）

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, source, body, stockID, stockName, format, seed, negatives, frameOffsets, strokes
        case caption, showsDate, blotches, developed, printFile, desk, tornFrom
        case takenAt, templateID, captionFont, location, tags, stickers, showsTags, showsLocation, showsTagStickers, editedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        source = try c.decode(.source, default: PhotoSource.screen)
        body = try c.decode(.body, default: CameraBody.instant)
        stockID = try c.decode(.stockID, default: FilmCatalog.defaultStock.id)
        stockName = try c.decode(.stockName, default: FilmCatalog.defaultStock.name)
        format = try c.decode(.format, default: body.format)
        seed = try c.decode(.seed, default: UInt64(0))
        negatives = try c.decode(.negatives, default: [])
        frameOffsets = try c.decode(.frameOffsets, default: [])
        strokes = try c.decode(.strokes, default: [])
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        showsDate = try c.decode(.showsDate, default: true)
        blotches = try c.decode(.blotches, default: [])
        developed = try c.decode(.developed, default: false)
        printFile = try c.decodeIfPresent(String.self, forKey: .printFile)
        desk = try c.decodeIfPresent(DeskPlacement.self, forKey: .desk)
        tornFrom = try c.decodeIfPresent(UUID.self, forKey: .tornFrom)
        takenAt = try c.decodeIfPresent(Date.self, forKey: .takenAt)
        templateID = try c.decodeIfPresent(String.self, forKey: .templateID)
        captionFont = try c.decode(.captionFont, default: CaptionFont.handwriting)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        tags = try c.decode(.tags, default: [])
        stickers = try c.decode(.stickers, default: [])
        showsTags = try c.decode(.showsTags, default: true)
        showsLocation = try c.decode(.showsLocation, default: true)
        showsTagStickers = try c.decode(.showsTagStickers, default: true)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(source, forKey: .source)
        try c.encode(body, forKey: .body)
        try c.encode(stockID, forKey: .stockID)
        try c.encode(stockName, forKey: .stockName)
        try c.encode(format, forKey: .format)
        try c.encode(seed, forKey: .seed)
        try c.encode(negatives, forKey: .negatives)
        try c.encode(frameOffsets, forKey: .frameOffsets)
        try c.encode(strokes, forKey: .strokes)
        try c.encodeIfPresent(caption, forKey: .caption)
        try c.encode(showsDate, forKey: .showsDate)
        try c.encode(blotches, forKey: .blotches)
        try c.encode(developed, forKey: .developed)
        try c.encodeIfPresent(printFile, forKey: .printFile)
        try c.encodeIfPresent(desk, forKey: .desk)
        try c.encodeIfPresent(tornFrom, forKey: .tornFrom)
        try c.encodeIfPresent(takenAt, forKey: .takenAt)
        try c.encodeIfPresent(templateID, forKey: .templateID)
        try c.encode(captionFont, forKey: .captionFont)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encode(tags, forKey: .tags)
        try c.encode(stickers, forKey: .stickers)
        try c.encode(showsTags, forKey: .showsTags)
        try c.encode(showsLocation, forKey: .showsLocation)
        try c.encode(showsTagStickers, forKey: .showsTagStickers)
        try c.encodeIfPresent(editedAt, forKey: .editedAt)
    }

    // MARK: Derived

    public var layout: PaperLayout { format.layout }

    /// 显示用的拍摄时间：用户改过就用改过的。
    public var displayDate: Date { takenAt ?? createdAt }

    /// 日期题字：「2026/11/23」。
    public var dateText: String {
        PhotoRecord.dateFormatter.string(from: displayDate)
    }

    /// 实际使用的模板 ID（没选过就是这个画幅的默认模板）。
    public var effectiveTemplateID: String {
        templateID ?? TemplateCatalog.defaultID(for: format)
    }

    /// 白边上印的标签行：「#阳光 #咖啡」（关闭或没有标签时为 nil）。
    public var tagLine: String? {
        guard showsTags else { return nil }
        let cleaned = tags.map(PhotoRecord.normalizedTag).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        return cleaned.map { "#" + $0 }.joined(separator: " ")
    }

    /// 白边上印的地点：「上海」（关闭或为空时为 nil）。
    public var locationLine: String? {
        guard showsLocation, let location else { return nil }
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 去掉首尾空白和开头的「#」/「＃」。
    public static func normalizedTag(_ tag: String) -> String {
        var t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = t.first, first == "#" || first == "＃" {
            t.removeFirst()
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// 每格的随机错位（大头贴机）。
    public static func makeFrameOffsets(count: Int, seed: UInt64, amount: Double) -> [FrameOffset] {
        var rng = SeededRandom(seed: seed ^ 0x0FF5E7)
        return (0..<count).map { _ in
            FrameOffset(dx: rng.signed() * amount, dy: rng.signed() * amount)
        }
    }

    /// 桌面上的随机倾斜角度。
    public static func randomTilt(seed: UInt64) -> Double {
        var rng = SeededRandom(seed: seed ^ 0x7117)
        return rng.signed() * 4.5
    }
}
