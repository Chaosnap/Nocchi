import SwiftUI

/// Nocchi 的配色：象牙白机身、炭黑镜头、细铬圈、陶土橙快门。
enum Palette {
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
}
