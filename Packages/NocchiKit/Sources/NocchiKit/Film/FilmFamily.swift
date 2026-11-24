import Foundation

/// 胶卷柜里的分组。由 `FilmStock.tags` 推出来，JSON 不需要新字段。
///
/// 标签约定（`FilmStocks.json`）：
/// - `booth`：大头贴（照相亭）相纸
/// - `instant`：即显相纸；再加 `mini` / `wide` 表示推荐迷你 / 宽幅相纸
/// - `bw`：黑白
/// - `cine` 或 `night`：夜景与电影胶片
/// - 其余：彩色负片
public enum FilmFamily: String, CaseIterable, Identifiable, Sendable {
    case instant
    case color
    case cine
    case bw
    case booth
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .instant: return "即显相纸"
        case .color: return "彩色负片"
        case .cine: return "夜景与电影"
        case .bw: return "黑白"
        case .booth: return "大头贴"
        case .custom: return "自定义 LUT"
        }
    }
}

public extension FilmStock {
    /// 胶卷柜分组。
    var family: FilmFamily {
        let set = Set(tags)
        if set.contains("custom") || lutFile != nil { return .custom }
        if set.contains("booth") { return .booth }
        if set.contains("instant") { return .instant }
        if set.contains("bw") || tone.monochrome { return .bw }
        if set.contains("cine") || set.contains("night") { return .cine }
        return .color
    }

    /// 推荐搭配的相纸（nil = 不限）。
    var recommendedFormat: FilmFormat? {
        let set = Set(tags)
        if set.contains("booth") { return .boothStrip }
        if set.contains("mini") { return .instantMini }
        if set.contains("wide") { return .instantWide }
        if set.contains("instant") { return .instantSquare }
        if set.contains("print") { return .landscape }
        return nil
    }
}

public extension FilmCatalog {
    /// 按分组排好的内置 + 自定义胶卷（分组顺序见 `FilmFamily.allCases`，组内保持 JSON 顺序）。
    static func grouped(_ stocks: [FilmStock]) -> [(family: FilmFamily, stocks: [FilmStock])] {
        var result: [(family: FilmFamily, stocks: [FilmStock])] = []
        for family in FilmFamily.allCases {
            let items = stocks.filter { $0.family == family }
            if !items.isEmpty {
                result.append((family: family, stocks: items))
            }
        }
        return result
    }
}
