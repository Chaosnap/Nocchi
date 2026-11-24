import CoreGraphics
import Foundation

// 装饰台的数据类型：涂鸦用的笔、题字字体、贴纸。
//
// 这些类型只描述「贴了什么、画了什么」，不关心怎么画。
// 画法见 `StickerArt`（贴纸）、`PhotoComposer`（成片合成）。
// 坐标约定与 `InkPoint` 相同：以相纸宽度为单位，原点在相纸左上角，
// x ∈ 0…1，y ∈ 0…1/aspect。

/// 涂鸦用的笔。全部是复古文具，不是「手绘风格」的装饰。
public enum InkTool: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 钢笔：实心墨水，压感控制粗细。
    case pen
    /// 马克笔：笔头宽，墨色略透。
    case marker
    /// 油性蜡笔：暗房里在印样上圈片用的那种，笔触带颗粒、边缘干涩。
    case grease
    /// 漆笔：不透明，可以在深色照片上写白字、金字。
    case paint

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pen: return "钢笔"
        case .marker: return "马克笔"
        case .grease: return "油性蜡笔"
        case .paint: return "漆笔"
        }
    }

    /// 界面图标（SF Symbols）。
    public var symbolName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .grease: return "pencil.and.scribble"
        case .paint: return "paintbrush.pointed.fill"
        }
    }

    /// 墨色不透明度。
    public var opacity: Double {
        switch self {
        case .pen: return 0.92
        case .marker: return 0.78
        case .grease: return 0.86
        case .paint: return 1.0
        }
    }

    /// 相对 `InkPoint.w` 的粗细倍数。
    public var widthScale: Double {
        switch self {
        case .pen: return 1.0
        case .marker: return 2.6
        case .grease: return 2.0
        case .paint: return 1.6
        }
    }
}

/// 题字字体。
public enum CaptionFont: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 手写：像用钢笔写在相纸白边上。
    case handwriting
    /// 打字机：复古打字机字模。
    case typewriter
    /// 铅字：老式印刷衬线体。
    case serif

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .handwriting: return "手写"
        case .typewriter: return "打字机"
        case .serif: return "铅字"
        }
    }
}

/// 贴纸分类（全部是复古印刷品的质感：凸版、珐琅、旧票据、纸胶带……不画线稿涂鸦）。
public enum StickerCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 徽章：珐琅 / 胶印圆标、放射光芒、复古水果与花卉印刷图样，带白色模切边。
    case badge
    /// 印章：橡皮章、邮戳、日期戳（墨色有斑驳、压印不均）。
    case stamp
    /// 旧物：邮票、票根、价签、行李牌、胶片片段、照片角。
    case ephemera
    /// 胶带：牛皮纸胶带、条纹 / 格纹纸胶带（半透明、两端撕口）。
    case tape
    /// 标签：凸字标签带（可以自己打字）。
    case label
    /// 表情：系统表情做成带白色模切边的乙烯贴纸。
    case emoji

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .badge: return "徽章"
        case .stamp: return "印章"
        case .ephemera: return "旧物"
        case .tape: return "胶带"
        case .label: return "标签"
        case .emoji: return "表情"
        }
    }
}

/// 一种贴纸（目录里的条目）。具体有哪些见 `StickerCatalog`。
public struct StickerKind: Identifiable, Hashable, Sendable {
    /// 稳定的 ID，写进照片记录里，改名不要改它。例如 `badge.sun`、`stamp.postmark`、`tape.kraft`、`label.text`、`emoji.🌸`。
    public let id: String
    /// 中文名。
    public let name: String
    public let category: StickerCategory
    /// 图案外框的宽高比（宽 / 高）。
    public let aspect: Double
    /// 默认宽度（相纸宽度单位）。
    public let defaultSize: Double
    /// 能不能换颜色（印章、标签带可以）。
    public let tintable: Bool
    /// 默认颜色（十六进制）；nil 表示图案自带配色。
    public let defaultTint: String?
    /// 能不能写字（凸字标签带、日期戳）。
    public let acceptsText: Bool
    /// 没有自定义文字时的默认文字。
    public let defaultText: String?

    public init(
        id: String,
        name: String,
        category: StickerCategory,
        aspect: Double = 1,
        defaultSize: Double = 0.2,
        tintable: Bool = false,
        defaultTint: String? = nil,
        acceptsText: Bool = false,
        defaultText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.aspect = aspect
        self.defaultSize = defaultSize
        self.tintable = tintable
        self.defaultTint = defaultTint
        self.acceptsText = acceptsText
        self.defaultText = defaultText
    }
}

/// 贴在相纸上的一枚贴纸。
public struct StickerPlacement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// `StickerKind.id`。
    public var kindID: String
    /// 中心点（相纸宽度单位，原点左上）。
    public var x: Double
    public var y: Double
    /// 宽度（相纸宽度单位）；高度 = size / kind.aspect。
    public var size: Double
    /// 顺时针旋转角度（度）。
    public var rotation: Double
    /// 换过的颜色（十六进制）；nil 用默认配色。
    public var tint: String?
    /// 自定义文字（标签带、日期戳）。
    public var text: String?
    /// 水平翻转。
    public var flipped: Bool

    public init(
        id: UUID = UUID(),
        kindID: String,
        x: Double,
        y: Double,
        size: Double,
        rotation: Double = 0,
        tint: String? = nil,
        text: String? = nil,
        flipped: Bool = false
    ) {
        self.id = id
        self.kindID = kindID
        self.x = x
        self.y = y
        self.size = size
        self.rotation = rotation
        self.tint = tint
        self.text = text
        self.flipped = flipped
    }

    private enum CodingKeys: String, CodingKey { case id, kindID, x, y, size, rotation, tint, text, flipped }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(.id, default: UUID())
        kindID = try c.decode(String.self, forKey: .kindID)
        x = try c.decode(.x, default: 0.5)
        y = try c.decode(.y, default: 0.5)
        size = try c.decode(.size, default: 0.2)
        rotation = try c.decode(.rotation, default: 0.0)
        tint = try c.decodeIfPresent(String.self, forKey: .tint)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        flipped = try c.decode(.flipped, default: false)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kindID, forKey: .kindID)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(size, forKey: .size)
        try c.encode(rotation, forKey: .rotation)
        try c.encodeIfPresent(tint, forKey: .tint)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encode(flipped, forKey: .flipped)
    }
}
