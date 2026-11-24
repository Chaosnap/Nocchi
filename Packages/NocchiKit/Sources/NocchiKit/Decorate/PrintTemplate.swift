import CoreGraphics
import Foundation

/// 相纸模板：成片的「纸」和「框」长什么样。
///
/// 模板只决定外观（纸色、纹样、窗口形状、印刷字样……），不改变画幅几何
/// （`PaperLayout` 的窗口位置不变），所以底片随时可以换模板重新合成。
/// 具体外观由 `PhotoComposer` 按 `style` 画出；屏幕上的 `PrintSurface` 用同一套渲染。
public struct PrintTemplate: Identifiable, Hashable, Sendable {
    /// 外观样式。每种样式的画法在 `PhotoComposer`（模板渲染）里。
    public enum Style: String, Hashable, Sendable {
        /// 经典：胶卷自带的相纸颜色。
        case classic
    }

    /// 稳定的 ID，写进照片记录里。
    public let id: String
    /// 中文名。
    public let name: String
    /// 一句话描述。
    public let note: String
    /// 适用的画幅。
    public let formats: [FilmFormat]
    public let style: Style
    /// 模板自带的相纸（nil = 用胶卷自带的相纸颜色与墨色）。
    public let paper: PaperStyle?

    public init(id: String, name: String, note: String, formats: [FilmFormat], style: Style, paper: PaperStyle? = nil) {
        self.id = id
        self.name = name
        self.note = note
        self.formats = formats
        self.style = style
        self.paper = paper
    }

    /// 这张照片实际用的相纸：模板自带的优先，否则用胶卷的。
    public func resolvedPaper(stockPaper: PaperStyle) -> PaperStyle {
        paper ?? stockPaper
    }
}

/// 全部模板。
public enum TemplateCatalog {
    /// 经典白边（所有画幅都可以用）。
    public static let classic = PrintTemplate(
        id: "classic",
        name: "经典",
        note: "胶卷自带的相纸，干干净净",
        formats: FilmFormat.allCases,
        style: .classic
    )

    public static let all: [PrintTemplate] = [classic]

    /// 某个画幅可用的模板（按目录顺序）。
    public static func templates(for format: FilmFormat) -> [PrintTemplate] {
        all.filter { $0.formats.contains(format) }
    }

    /// 按 ID 找模板；找不到（或 nil）返回 nil。
    public static func template(id: String?) -> PrintTemplate? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// 按 ID 找模板，找不到就用这个画幅的默认模板。
    public static func resolve(id: String?, format: FilmFormat) -> PrintTemplate {
        if let template = template(id: id), template.formats.contains(format) { return template }
        return template(id: defaultID(for: format)) ?? classic
    }

    /// 每个画幅的默认模板。
    public static func defaultID(for format: FilmFormat) -> String {
        classic.id
    }
}
