import AppKit
import NocchiKit

/// 共享的照片库与暗房。照片只存在本机：
/// - 记录、底片、LUT：`~/Library/Application Support/Nocchi`
/// - 带白边的成片：默认 `~/Pictures/Nocchi/<年-月>/`，可以在设置 → 通用 → 存储里换（`PrintsLocation`）
enum Services {
    static let library: PhotoLibrary = {
        let fm = FileManager.default
        // 截图工作室（GitHub Actions）用一个临时照片库，不碰真正的照片。
        if let override = ProcessInfo.processInfo.environment["NOCCHI_LIBRARY_ROOT"], !override.isEmpty {
            let base = URL(fileURLWithPath: override, isDirectory: true)
            if let library = try? PhotoLibrary(root: base.appendingPathComponent("data", isDirectory: true), printsRoot: base.appendingPathComponent("prints", isDirectory: true)) {
                return library
            }
        }
        let support = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let root = support.appendingPathComponent("Nocchi", isDirectory: true)
        let prints = PrintsLocation.customRootForLaunch() ?? PrintsLocation.defaultRoot
        if let library = try? PhotoLibrary(root: root, printsRoot: prints) {
            return library
        }
        let fallback = fm.temporaryDirectory.appendingPathComponent("Nocchi", isDirectory: true)
        // swiftlint:disable:next force_try
        return try! PhotoLibrary(root: fallback.appendingPathComponent("data"), printsRoot: fallback.appendingPathComponent("prints"))
    }()

    static let processor: FilmProcessor = FilmProcessor(lutDirectory: library.lutsDirectory)

    /// 用户导入的字体（照片库的 `fonts/`，启动时在本进程注册）。
    static let fonts = CustomFontStore(directory: library.root.appendingPathComponent("fonts", isDirectory: true))

    /// 「我的贴纸」（照片库的 `stickers/`）；启动时把它注入 `StickerArt.customProvider`。
    static let stickers = CustomStickerStore(directory: library.root.appendingPathComponent("stickers", isDirectory: true))
}

/// 成片放在哪里：默认「图片/Nocchi」，设置里可以换到别的文件夹（外接盘、网盘同步文件夹……）。
/// 换的时候已有的成片一起搬过去（`PhotoLibrary.relocatePrints(to:)`），位置记在 UserDefaults。
enum PrintsLocation {
    static let storageKey = "storage.printsRoot"

    static var defaultRoot: URL {
        let pictures = (try? FileManager.default.url(for: .picturesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return pictures.appendingPathComponent("Nocchi", isDirectory: true)
    }

    /// 设置里选的位置（nil = 默认）。
    static var customRoot: URL? {
        guard let path = UserDefaults.standard.string(forKey: storageKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// 这次启动时找不到的自定义位置（外接盘没插上等）：这次先用默认位置，设置里提示一句。
    nonisolated(unsafe) private(set) static var unavailableRoot: URL?

    /// 启动时用的自定义位置：它所在的文件夹要存在（外接盘没插上时不在 /Volumes 下面凭空建文件夹）。
    static func customRootForLaunch() -> URL? {
        guard let custom = customRoot else { return nil }
        var isFolder: ObjCBool = false
        let parent = custom.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isFolder), isFolder.boolValue else {
            unavailableRoot = custom
            return nil
        }
        return custom
    }

    /// 用户选的文件夹 → 真正放成片的文件夹：选的就叫 Nocchi，或者是空文件夹，就直接用；否则在里面建一个「Nocchi」。
    static func printsFolder(forChosen folder: URL) -> URL {
        if folder.lastPathComponent == "Nocchi" {
            return folder
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        if contents.allSatisfy({ $0.hasPrefix(".") }) {
            return folder
        }
        return folder.appendingPathComponent("Nocchi", isDirectory: true)
    }

    /// 记下新位置（默认位置就清掉设置）。
    static func remember(_ url: URL) {
        if url.standardizedFileURL.path == defaultRoot.standardizedFileURL.path {
            UserDefaults.standard.removeObject(forKey: storageKey)
        } else {
            UserDefaults.standard.set(url.path, forKey: storageKey)
        }
        unavailableRoot = nil
    }
}

/// 音效（安静模式由 `SoundPlayer.isMuted` 控制）。
enum Sound {
    static func play(_ effect: SoundEffect, duration: Double? = nil) {
        SoundPlayer.shared.play(effect, duration: duration)
    }
}

/// 压感触控板的触感反馈。
enum Haptics {
    static func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func heavy() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    static func align() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
