import AppKit
import SwiftUI

/// Nocchi 的配色：象牙白机身、炭黑镜头、细铬圈、陶土橙快门；v0.2 加入复古冲印店的物料色。
///
/// 设计规范见 `docs/DESIGN.md`。界面里不要直接写十六进制颜色，统一从这里取。
enum Palette {
    // MARK: 机身

    /// 机身象牙白。
    static let ivory = Color(red: 0.925, green: 0.902, blue: 0.855)        // #ECE6DA
    static let ivoryLight = Color(red: 0.949, green: 0.933, blue: 0.902)   // #F2EEE6
    static let ivoryShade = Color(red: 0.851, green: 0.820, blue: 0.761)   // #D9D1C2
    /// 炭黑（镜头、出片口、字）。
    static let charcoal = Color(red: 0.118, green: 0.118, blue: 0.118)     // #1E1E1E
    static let lensBlack = Color(red: 0.071, green: 0.071, blue: 0.071)    // #121212
    /// 陶土橙快门键。
    static let terracotta = Color(red: 0.769, green: 0.349, blue: 0.231)   // #C4593B
    static let terracottaLight = Color(red: 0.910, green: 0.537, blue: 0.420) // #E8896B
    /// 铬。
    static let chromeLight = Color(white: 0.93)
    static let chromeDark = Color(white: 0.52)
    /// 桌面浅灰（带点阵）。
    static let desk = Color(red: 0.851, green: 0.843, blue: 0.827)         // #D9D7D3
    static let deskDot = Color(red: 0.776, green: 0.765, blue: 0.749)      // #C6C3BF

    // MARK: 复古冲印店（v0.2）

    /// 相册 / 装饰台的纸色。
    static let paper = Color(hex: 0xF4EEE1)
    static let paperDeep = Color(hex: 0xEAE2D2)
    /// 发丝线（表格线、分隔线）。
    static let hairline = Color(hex: 0xD8CFBF)
    /// 正文墨色（暖黑）与次要文字。
    static let ink = Color(hex: 0x2E2924)
    static let inkSoft = Color(hex: 0x7A6F64)
    /// 70 年代辅助色。
    static let mustard = Color(hex: 0xD9A441)
    static let petrol = Color(hex: 0x2F5F5C)
    static let olive = Color(hex: 0x6F6A3A)
    static let cobalt = Color(hex: 0x2F4C8A)
    /// 印刷红（挂历的周末、日期戳）。
    static let printRed = Color(hex: 0xB23A2A)
    /// 日期机的橙色数码字 / 胶片片边字。
    static let dateOrange = Color(hex: 0xE8892F)
    /// 胡桃木。
    static let walnut = Color(hex: 0x4A3021)
    static let walnutLight = Color(hex: 0x7A5236)
    static let walnutDeep = Color(hex: 0x2A1C14)
    /// 黄铜。
    static let brass = Color(hex: 0xB8955A)
    static let brassLight = Color(hex: 0xE3C98F)
    /// 皮革（装饰台工具托盘）。
    static let leather = Color(hex: 0x2A211B)
    /// 光台的暖白光。
    static let lightbox = Color(hex: 0xFFF8EA)
    static let lightboxEdge = Color(hex: 0xF0E4CB)
    /// 暗房安全灯。
    static let safelight = Color(hex: 0xB0352A)
}

/// 复古字体。拉丁字母用老式衬线 / 打字机，中文用宋体，数字可以用 Didot。
///
/// 不要用手写体做界面文字（相纸上的「手写题字」除外）。
enum RetroFont {
    /// 大标题数字与拉丁字母（挂历上的大号月份、相册字标）。
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Didot", size: size).weight(weight)
    }

    /// 中文标题：宋体。
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Songti SC", size: size).weight(weight)
    }

    /// 打字机：日期、编号、片边字、标签。
    static func typewriter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("American Typewriter", size: size).weight(weight)
    }

    /// 等宽：计数器、规格。
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Courier New", size: size).weight(weight)
    }

    /// 凸字标签带（标签机打出来的白色凸字）。
    static func label(_ size: CGFloat) -> Font {
        .custom("Futura-CondensedExtraBold", size: size)
    }
}

extension Color {
    /// 用 0xRRGGBB 写颜色。
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
