import CoreText
import Foundation

/// 只用系统里已经装好的字体（以及用户导入、已在本进程注册的字体）。
///
/// 引用一个没装的字体——尤其是 macOS 的「可下载字体」（楷体、翩翩体、仿宋……）——时，Core Text 可能会去请求
/// 系统字体服务自动激活 / 下载它；在没有界面的环境里（CI 上的测试进程）这个请求会一直等下去。
/// 所以先查一遍系统里实际可用的字体名（缓存起来，注册新字体后刷新），只用查得到的。线程安全。
public enum FontBook {
    private static let lock = NSLock()
    private static var cachedPostScriptNames: Set<String>?
    private static var cachedFamilies: Set<String>?

    /// 已安装字体的 PostScript 名。
    public static var postScriptNames: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedPostScriptNames { return cached }
        let names = Set((CTFontManagerCopyAvailablePostScriptNames() as? [String]) ?? [])
        cachedPostScriptNames = names
        return names
    }

    /// 已安装字体的家族名。
    public static var families: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedFamilies { return cached }
        let names = Set((CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? [])
        cachedFamilies = names
        return names
    }

    /// 按字母排好的家族名（字体选择器用）。
    public static var sortedFamilies: [String] {
        families.filter { !$0.hasPrefix(".") }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

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
        let available = families
        return names.filter { available.contains($0) }
    }

    /// 字体文件里有哪些家族（不注册）。
    public static func familyNames(in url: URL) -> [String] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        var names: [String] = []
        for descriptor in descriptors {
            if let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String, !names.contains(family) {
                names.append(family)
            }
        }
        return names
    }

    /// 在本进程里注册字体文件（用户导入的字体），并刷新已安装字体的清单。返回注册上的家族名。
    @discardableResult
    public static func register(_ urls: [URL]) -> [String] {
        var registered: [String] = []
        for url in urls {
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            let alreadyThere = (error?.takeRetainedValue()).map { CFErrorGetCode($0) == CTFontManagerError.alreadyRegistered.rawValue } ?? false
            if ok || alreadyThere {
                registered.append(contentsOf: familyNames(in: url))
            }
        }
        invalidate()
        return registered
    }

    /// 取消注册（删掉导入的字体时）。
    public static func unregister(_ urls: [URL]) {
        for url in urls {
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        }
        invalidate()
    }

    /// 字体清单变了：下次重新查。
    public static func invalidate() {
        lock.lock()
        cachedPostScriptNames = nil
        cachedFamilies = nil
        lock.unlock()
    }
}

/// 用户导入的字体：复制到照片库的 `fonts/` 目录，启动时注册（只在本进程有效，不装进系统）。
public final class CustomFontStore: @unchecked Sendable {
    public let directory: URL
    private let fileManager = FileManager.default
    private static let extensions: Set<String> = ["ttf", "otf", "ttc", "otc"]

    public init(directory: URL) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 已导入的字体文件。
    public var fontFiles: [URL] {
        let items = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return items.filter { Self.extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 已导入字体的家族名。
    public var families: [String] {
        var names: [String] = []
        for url in fontFiles {
            for family in FontBook.familyNames(in: url) where !names.contains(family) {
                names.append(family)
            }
        }
        return names
    }

    /// 注册全部已导入的字体（App 启动时调用）。
    @discardableResult
    public func registerAll() -> [String] {
        FontBook.register(fontFiles)
    }

    public enum ImportError: Error, Equatable {
        case unsupported
        case unreadable
    }

    /// 导入一个字体文件：检查能读出字体 → 复制进来 → 注册。返回其中的家族名。
    @discardableResult
    public func importFont(from url: URL) throws -> [String] {
        guard Self.extensions.contains(url.pathExtension.lowercased()) else { throw ImportError.unsupported }
        let names = FontBook.familyNames(in: url)
        guard !names.isEmpty else { throw ImportError.unreadable }
        var destination = directory.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            let stem = url.deletingPathExtension().lastPathComponent
            destination = directory.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(6)).\(url.pathExtension)")
        }
        try fileManager.copyItem(at: url, to: destination)
        FontBook.register([destination])
        return names
    }

    /// 删掉某个家族的字体文件（并取消注册）。
    public func remove(family: String) {
        let files = fontFiles.filter { FontBook.familyNames(in: $0).contains(family) }
        FontBook.unregister(files)
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}
