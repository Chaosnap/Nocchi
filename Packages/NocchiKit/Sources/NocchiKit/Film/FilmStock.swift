import Foundation

/// LUT 之外的胶片效果，每项 0…1。
public struct FilmEffects: Codable, Hashable, Sendable {
    /// 颗粒强度。
    public var grain: Float
    /// 颗粒尺寸（1 = 单像素，越大越粗）。
    public var grainSize: Float
    /// 高光红色光晕（Halation）。
    public var halation: Float
    /// 柔焦 / 泛光。
    public var bloom: Float
    /// 暗角。
    public var vignette: Float
    /// 漏光。
    public var lightLeak: Float

    public init(grain: Float = 0, grainSize: Float = 1, halation: Float = 0, bloom: Float = 0, vignette: Float = 0, lightLeak: Float = 0) {
        self.grain = grain
        self.grainSize = grainSize
        self.halation = halation
        self.bloom = bloom
        self.vignette = vignette
        self.lightLeak = lightLeak
    }

    public static let clean = FilmEffects()

    private enum CodingKeys: String, CodingKey {
        case grain, grainSize, halation, bloom, vignette, lightLeak
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FilmEffects()
        grain = try c.decode(.grain, default: d.grain)
        grainSize = try c.decode(.grainSize, default: d.grainSize)
        halation = try c.decode(.halation, default: d.halation)
        bloom = try c.decode(.bloom, default: d.bloom)
        vignette = try c.decode(.vignette, default: d.vignette)
        lightLeak = try c.decode(.lightLeak, default: d.lightLeak)
    }
}

/// 相纸样式：白边颜色与默认墨水颜色。
public struct PaperStyle: Codable, Hashable, Sendable {
    public var color: String
    public var ink: String

    public init(color: String = "#F7F4EC", ink: String = "#2B2A28") {
        self.color = color
        self.ink = ink
    }

    public static let classic = PaperStyle()

    public var paperRGB: RGB { RGB(hex: color) ?? RGB(0.97, 0.96, 0.93) }
    public var inkRGB: RGB { RGB(hex: ink) ?? RGB(0.17, 0.16, 0.16) }
    /// 深色相纸（夜景胶卷的黑边）。
    public var isDark: Bool { ColorMath.luminance(paperRGB) < 0.4 }

    private enum CodingKeys: String, CodingKey { case color, ink }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PaperStyle()
        color = try c.decode(.color, default: d.color)
        ink = try c.decode(.ink, default: d.ink)
    }
}

/// 一卷胶卷：名称、感光度、张数、色调配方与效果。
///
/// 名字全部原创，不使用真实胶片品牌。
public struct FilmStock: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var englishName: String
    public var iso: Int
    public var exposures: Int
    public var summary: String
    /// 用于 UI 色卡的三种代表色。
    public var swatch: [String]
    public var tags: [String]
    public var tone: ToneRecipe
    /// 用户导入的 `.cube` 文件名（位于照片库的 LUT 目录）；有值时优先于 `tone`。
    public var lutFile: String?
    public var lutIntensity: Float
    public var effects: FilmEffects
    public var paper: PaperStyle

    public init(
        id: String,
        name: String,
        englishName: String = "",
        iso: Int = 400,
        exposures: Int = 12,
        summary: String = "",
        swatch: [String] = [],
        tags: [String] = [],
        tone: ToneRecipe = .neutral,
        lutFile: String? = nil,
        lutIntensity: Float = 1,
        effects: FilmEffects = .clean,
        paper: PaperStyle = .classic
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.iso = iso
        self.exposures = exposures
        self.summary = summary
        self.swatch = swatch
        self.tags = tags
        self.tone = tone
        self.lutFile = lutFile
        self.lutIntensity = lutIntensity
        self.effects = effects
        self.paper = paper
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, englishName, iso, exposures, summary, swatch, tags, tone, lutFile, lutIntensity, effects, paper
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        englishName = try c.decode(.englishName, default: "")
        iso = try c.decode(.iso, default: 400)
        exposures = try c.decode(.exposures, default: 12)
        summary = try c.decode(.summary, default: "")
        swatch = try c.decode(.swatch, default: [])
        tags = try c.decode(.tags, default: [])
        tone = try c.decode(.tone, default: .neutral)
        lutFile = try c.decodeIfPresent(String.self, forKey: .lutFile)
        lutIntensity = try c.decode(.lutIntensity, default: 1)
        effects = try c.decode(.effects, default: .clean)
        paper = try c.decode(.paper, default: .classic)
    }

    /// UI 显示用：「暖阳 400」。
    public var displayName: String { name }

    /// 是否黑白胶卷。
    public var isMonochrome: Bool { tone.monochrome }

    /// 缓存键：配方或 LUT 改变时变化。
    public var lookKey: String {
        "\(id)|\(lutFile ?? "-")|\(lutIntensity)|\(tone.hashValue)"
    }

    /// 用户导入 `.cube` 时生成的自定义胶卷。
    public static func custom(fromLUT fileName: String, title: String?, intensity: Float = 1) -> FilmStock {
        let base = (title?.isEmpty == false ? title! : (fileName as NSString).deletingPathExtension)
        return FilmStock(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: base,
            englishName: base,
            iso: 200,
            exposures: 24,
            summary: "自定义 LUT 胶卷",
            swatch: ["#D8CFC0", "#9A8C7A", "#3A3530"],
            tags: ["custom"],
            tone: .neutral,
            lutFile: fileName,
            lutIntensity: intensity,
            effects: FilmEffects(grain: 0.15, grainSize: 1.1, vignette: 0.15),
            paper: .classic
        )
    }
}

/// 内置胶卷目录（`Resources/FilmStocks.json`）。
public enum FilmCatalog {
    struct File: Codable {
        var version: Int
        var stocks: [FilmStock]
    }

    /// JSON 读取失败时的兜底胶卷。
    public static let fallback = FilmStock(
        id: "cream-600",
        name: "奶油 600",
        englishName: "Cream 600",
        iso: 600,
        exposures: 10,
        summary: "即显相纸的经典奶油色",
        swatch: ["#F2D9A8", "#9FB49C", "#5A4B3C"],
        tags: ["instant", "warm"],
        tone: ToneRecipe(exposure: 0.1, temperature: 0.25, tint: -0.05, contrast: 1.05, blackLift: 0.06, whiteCap: 0.96, saturation: 0.9),
        effects: FilmEffects(grain: 0.18, grainSize: 1.2, halation: 0.1, bloom: 0.15, vignette: 0.25)
    )

    /// 内置胶卷（按 JSON 顺序）。
    public static let builtIn: [FilmStock] = {
        guard let url = Bundle.module.url(forResource: "FilmStocks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stocks = try? decode(data), !stocks.isEmpty else {
            return [fallback]
        }
        return stocks
    }()

    public static func decode(_ data: Data) throws -> [FilmStock] {
        try JSONDecoder().decode(File.self, from: data).stocks
    }

    public static var defaultStock: FilmStock { builtIn.first ?? fallback }

    /// 按 id 查找（先查自定义胶卷，再查内置），找不到时返回默认胶卷。
    public static func stock(id: String, custom: [FilmStock] = []) -> FilmStock {
        if let s = custom.first(where: { $0.id == id }) { return s }
        if let s = builtIn.first(where: { $0.id == id }) { return s }
        return defaultStock
    }
}
