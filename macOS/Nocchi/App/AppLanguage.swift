import AppKit
import NocchiKit

/// 界面语言：简体中文（默认）或英文（设置 → 通用 → 语言）。
///
/// 用的是 Apple 的标准本地化：中文原文就是键，英文在 `Resources/en.lproj/Localizable.strings`
/// （由 `scripts/i18n/strings.py build` 从 `scripts/i18n/en.json` 生成）。一个进程只用一种语言：
/// 启动时把 Nocchi 自己的 `AppleLanguages` 设成选的语言（和「系统设置 → 语言与地区 → App」是同一个键），
/// 换语言要重新打开。
enum AppLanguage {
    /// 启动时（`NocchiMacApp.init`，还没查过任何翻译之前）调用：没选过就是中文——系统是英文也一样。
    static func applyAtLaunch() {
        UserDefaults.standard.set([UILanguage.current.rawValue], forKey: "AppleLanguages")
    }

    /// 设置里存下来的语言（这个进程实际在用的是 `UILanguage.current`）。
    static var saved: UILanguage {
        UserDefaults.standard.string(forKey: UILanguage.storageKey).flatMap(UILanguage.init(rawValue:)) ?? .chinese
    }

    /// 设置里换语言：记下来，问要不要现在重新打开。提示用新语言写（用户选的就是看得懂的那种）。
    @MainActor
    static func choose(_ language: UILanguage) {
        guard language != saved else { return }
        UserDefaults.standard.set(language.rawValue, forKey: UILanguage.storageKey)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        guard language != UILanguage.current else { return }
        let alert = NSAlert()
        if language.isEnglish {
            alert.messageText = "Relaunch Nocchi in English?" // i18n-ok：用新语言写
            alert.informativeText = "The new language takes effect when Nocchi opens again. Your photos are not affected." // i18n-ok
            alert.addButton(withTitle: "Relaunch Now") // i18n-ok
            alert.addButton(withTitle: "Later") // i18n-ok
        } else {
            alert.messageText = "重新打开 Nocchi，换成简体中文？" // i18n-ok：用新语言写
            alert.informativeText = "重新打开后界面换成简体中文，照片不受影响。" // i18n-ok
            alert.addButton(withTitle: "现在重新打开") // i18n-ok
            alert.addButton(withTitle: "稍后") // i18n-ok
        }
        if alert.runModal() == .alertFirstButtonReturn {
            relaunch()
        }
    }

    /// 退出，过一会儿用 `open` 再打开自己。
    @MainActor
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.8; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
