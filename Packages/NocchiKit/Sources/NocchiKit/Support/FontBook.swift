import CoreText
import Foundation

/// 只用系统里已经装好的字体。
///
/// 引用一个没装的字体——尤其是 macOS 的「可下载字体」（楷体、翩翩体、仿宋……）——时，Core Text 可能会去请求
/// 系统字体服务自动激活 / 下载它；在没有界面的环境里（CI 上的测试进程）这个请求会一直等下去。
/// 所以先查一遍系统里实际可用的字体名（只查一次），只用查得到的。
public enum FontBook {
    /// 已安装字体的 PostScript 名。
    public static let postScriptNames: Set<String> = {
        Set((CTFontManagerCopyAvailablePostScriptNames() as? [String]) ?? [])
    }()

    /// 已安装字体的家族名。
    public static let families: Set<String> = {
        Set((CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? [])
    }()

    /// 这个名字（PostScript 名或家族名）的字体装了没有。
    public static func isInstalled(_ name: String) -> Bool {
        postScriptNames.contains(name) || families.contains(name)
    }

    /// 候选名字里第一个装了的字体；都没装时用 Helvetica。
    public static func font(_ names: [String], size: CGFloat) -> CTFont {
        for name in names where isInstalled(name) {
            return CTFontCreateWithName(name as CFString, size, nil)
        }
        return CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    /// 只留下装了的家族（用来拼后备字体列表）。
    public static func installedFamilies(_ names: [String]) -> [String] {
        names.filter { families.contains($0) }
    }
}
