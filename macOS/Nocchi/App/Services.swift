import AppKit
import NocchiKit

/// 共享的照片库与暗房。照片只存在本机：
/// - 记录、底片、LUT：`~/Library/Application Support/Nocchi`
/// - 带白边的成片：`~/Pictures/Nocchi/<年-月>/`
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
        let pictures = (try? fm.url(for: .picturesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let root = support.appendingPathComponent("Nocchi", isDirectory: true)
        let prints = pictures.appendingPathComponent("Nocchi", isDirectory: true)
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
