import Foundation

/// 界面语言：简体中文（默认）或英文。
///
/// App 在「设置 → 通用 → 语言」里切换：写下 `storageKey`，同时把 Nocchi 自己的 `AppleLanguages` 设成同一种语言，
/// 再重新打开——所以一个进程从头到尾只用一种语言，这里只在第一次用到时读一次。
/// 单元测试里没有设置过，就是中文。
public enum UILanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    public var id: String { rawValue }

    /// 设置里存语言的键（macOS 与 iOS 两个 App 共用）。
    public static let storageKey = "app.language"

    /// 这个进程用的界面语言。
    public static let current: UILanguage = {
        if let raw = UserDefaults.standard.string(forKey: storageKey), let language = UILanguage(rawValue: raw) {
            return language
        }
        return .chinese
    }()

    /// 语言自己的名字（不翻译：在英文界面里也写「简体中文」）。
    public var nativeName: String {
        switch self {
        case .chinese: return "简体中文" // i18n-ok：语言自己的名字
        case .english: return "English"
        }
    }

    public var locale: Locale { Locale(identifier: rawValue) }

    public var isEnglish: Bool { self == .english }
}

/// 动态文字的翻译（不是写在源码里的字面量，比如胶卷简介）：键是中文原文，英文在 App 的
/// `en.lproj/Localizable.strings` 里；中文界面直接返回原文，找不到翻译时也是原文。
/// 写在源码里的字用 `String(localized:)`（SwiftUI 的 `Text("…")` 会自己查表）。
public enum Localized {
    public static func string(_ key: String) -> String {
        guard UILanguage.current.isEnglish, !key.isEmpty else { return key }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
