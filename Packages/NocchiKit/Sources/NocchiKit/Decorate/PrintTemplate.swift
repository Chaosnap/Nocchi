import CoreGraphics
import Foundation

/// 相纸模板：成片的「纸」和「框」长什么样。
///
/// 模板只决定外观（纸色、纹样、窗口形状、印刷字样……），不改变画幅几何
/// （`PaperLayout` 的窗口位置不变），所以底片随时可以换模板重新合成。
/// 具体外观由 `TemplateArt` 画出；屏幕上的 `PrintSurface` 与导出的成片用同一套渲染。
public struct PrintTemplate: Identifiable, Hashable, Sendable {
    /// 外观样式。每种样式的画法在 `TemplateArt` 里。
    public enum Style: String, Hashable, Sendable {
        /// 经典：胶卷自带的相纸颜色。
        case classic
        /// 炭黑相纸、象牙白字。
        case noir
        /// 牛皮纸。
        case kraft
        /// 50 年代照片的扇贝毛边 + 压纹边框。
        case deckle
        /// 日期机：照片右下角的橙色数码日期。
        case datebook
        /// 35mm 胶片框：黑色片基、齿孔、橙色片边字。
        case filmframe
        /// 邮票：齿孔外缘、面值、邮戳。
        case postage
        /// 70 年代条纹。
        case seventies
        /// 黑卡纸老相册 + 照片角。
        case album
        /// 照相馆卡纸：深棕卡、金色双线框。
        case cabinet
        /// 老照相亭：奶油白纸 + 编号。
        case boothClassic
        /// 黑白照相亭：黑纸 + 白发丝边。
        case boothNoir
        /// 情人节：心形窗口 + 蕾丝花边。
        case boothHeart
        /// 金星：墨蓝纸 + 烫金小星。
        case boothStars
        /// 生日快乐：横幅与三角彩旗。
        case boothBirthday
        /// 新年快乐：朱红纸 + 金色回纹。
        case boothNewYear
    }

    /// 窗口（照片区域）的形状。
    public enum WindowShape: String, Hashable, Sendable {
        case rect
        case heart
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

    /// 相纸外轮廓不是圆角矩形（毛边、邮票齿孔）。
    public var hasCustomOutline: Bool {
        style == .deckle || style == .postage
    }

    public var windowShape: WindowShape {
        style == .boothHeart ? .heart : .rect
    }

    /// 深色相纸上的浅色墨（窗口发丝边等细节用浅色）。
    public var isDarkPaper: Bool {
        switch style {
        case .noir, .filmframe, .album, .cabinet, .boothNoir, .boothStars, .boothNewYear: return true
        default: return false
        }
    }
}

/// 全部模板。
public enum TemplateCatalog {
    private static let everyFormat: [FilmFormat] = FilmFormat.allCases
    private static let instant: [FilmFormat] = [.instantSquare, .instantMini, .instantWide]
    private static let single: [FilmFormat] = [.instantSquare, .instantMini, .instantWide, .landscape]
    private static let booth: [FilmFormat] = [.boothStrip, .boothGrid]

    /// 经典白边（所有画幅都可以用）。
    public static let classic = PrintTemplate(
        id: "classic",
        name: String(localized: "经典"),
        note: String(localized: "胶卷自带的相纸，干干净净"),
        formats: FilmFormat.allCases,
        style: .classic
    )

    public static let all: [PrintTemplate] = [
        classic,
        PrintTemplate(id: "noir", name: String(localized: "炭黑"), note: String(localized: "炭黑相纸、象牙白字，照片更跳"), formats: everyFormat, style: .noir,
                      paper: PaperStyle(color: "#1C1B1A", ink: "#EDE6D8")),
        PrintTemplate(id: "kraft", name: String(localized: "牛皮纸"), note: String(localized: "带纤维的牛皮纸、深棕墨水"), formats: everyFormat, style: .kraft,
                      paper: PaperStyle(color: "#B99872", ink: "#33261B")),
        PrintTemplate(id: "deckle", name: String(localized: "毛边相纸"), note: String(localized: "50 年代照片的扇贝毛边和压纹边框"), formats: single, style: .deckle,
                      paper: PaperStyle(color: "#F1E8D6", ink: "#3A2E24")),
        PrintTemplate(id: "datebook", name: String(localized: "日期机"), note: String(localized: "照片右下角印上橙色的数码日期"), formats: single, style: .datebook),
        PrintTemplate(id: "filmframe", name: String(localized: "胶片框"), note: String(localized: "黑色片基、齿孔和橙色片边字"), formats: everyFormat, style: .filmframe,
                      paper: PaperStyle(color: "#17110D", ink: "#E39B3A")),
        PrintTemplate(id: "postage", name: String(localized: "邮票"), note: String(localized: "齿孔边、面值和一枚邮戳"), formats: instant, style: .postage,
                      paper: PaperStyle(color: "#F4EEDF", ink: "#2E2924")),
        PrintTemplate(id: "seventies", name: String(localized: "70 年代条纹"), note: String(localized: "底边三道芥末、陶土、胡桃色条纹"), formats: everyFormat, style: .seventies),
        PrintTemplate(id: "album", name: String(localized: "老相册"), note: String(localized: "黑卡纸相册页和四个照片角"), formats: single, style: .album,
                      paper: PaperStyle(color: "#1B1A18", ink: "#EDE6D8")),
        PrintTemplate(id: "cabinet", name: String(localized: "照相馆卡纸"), note: String(localized: "深棕卡纸、烫金双线框和店名"), formats: [.instantSquare, .instantMini], style: .cabinet,
                      paper: PaperStyle(color: "#3B2A20", ink: "#D9BC7A")),
        PrintTemplate(id: "booth-classic", name: String(localized: "老照相亭"), note: String(localized: "奶油白相纸，底下印着编号"), formats: booth, style: .boothClassic,
                      paper: PaperStyle(color: "#F6F1E6", ink: "#2E2924")),
        PrintTemplate(id: "booth-noir", name: String(localized: "黑白照相亭"), note: String(localized: "黑色相纸和白色发丝边"), formats: booth, style: .boothNoir,
                      paper: PaperStyle(color: "#141313", ink: "#EDEDED")),
        PrintTemplate(id: "booth-heart", name: String(localized: "情人节"), note: String(localized: "心形窗口和复古蕾丝花边"), formats: booth, style: .boothHeart,
                      paper: PaperStyle(color: "#F2D7D0", ink: "#7A3B3B")),
        PrintTemplate(id: "booth-stars", name: String(localized: "金星"), note: String(localized: "墨蓝相纸上撒满烫金小星"), formats: booth, style: .boothStars,
                      paper: PaperStyle(color: "#1E2A44", ink: "#E3C98F")),
        PrintTemplate(id: "booth-birthday", name: String(localized: "生日快乐"), note: String(localized: "复古横幅和三角彩旗"), formats: booth, style: .boothBirthday,
                      paper: PaperStyle(color: "#F7EFE3", ink: "#2E2924")),
        PrintTemplate(id: "booth-newyear", name: String(localized: "新年快乐"), note: String(localized: "朱红相纸和金色回纹"), formats: booth, style: .boothNewYear,
                      paper: PaperStyle(color: "#A8262A", ink: "#F2D08A"))
    ]

    /// 某个画幅可用的模板（按目录顺序）。
    public static func templates(for format: FilmFormat) -> [PrintTemplate] {
        all.filter { $0.formats.contains(format) }
    }

    /// 按 ID 找模板；找不到（或 nil）返回 nil。
    public static func template(id: String?) -> PrintTemplate? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// 按 ID 找模板，找不到或不适用于这个画幅时用这个画幅的默认模板。
    public static func resolve(id: String?, format: FilmFormat) -> PrintTemplate {
        if let template = template(id: id), template.formats.contains(format) { return template }
        return template(id: defaultID(for: format)) ?? classic
    }

    /// 每个画幅的默认模板。
    public static func defaultID(for format: FilmFormat) -> String {
        classic.id
    }
}
