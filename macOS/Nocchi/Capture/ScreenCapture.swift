import AppKit
import NocchiKit

/// 屏幕快门：调用系统的框选截图（空格切换到窗口模式，Esc 取消）。
enum ScreenShutter {
    static func captureInteractive() async -> CGImage? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nocchi-shot-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i 交互框选，-x 不播放系统快门声（用我们自己的），-o 窗口模式下不带阴影
        process.arguments = ["-i", "-x", "-o", "-t", "png", url.path]
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume()
            }
        }
        defer { try? FileManager.default.removeItem(at: url) }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return ImageIOKit.load(url, maxPixel: 3200)
    }
}

/// 接管系统截图：监听 Spotlight 元数据里的新截图（⇧⌘3 / ⇧⌘4 / ⇧⌘5）。
@MainActor
final class ScreenshotWatcher {
    static let shared = ScreenshotWatcher()

    private var query: NSMetadataQuery?
    private var seen = Set<String>()
    private var startedAt = Date()
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    private func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        startedAt = Date()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.absorb(initial: true) }
        })
        observers.append(center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.absorb(initial: false) }
        })
        self.query = query
        query.start()
    }

    private func stop() {
        query?.stop()
        query = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func absorb(initial: Bool) {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !seen.contains(path) else { continue }
            seen.insert(path)
            if initial { continue }
            let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? Date()
            guard created >= startedAt.addingTimeInterval(-2) else { continue }
            let url = URL(fileURLWithPath: path)
            Task { @MainActor in
                // 等系统把文件写完。
                try? await Task.sleep(nanoseconds: 700_000_000)
                Darkroom.shared.developSystemScreenshot(at: url)
            }
        }
    }
}

/// 白屏闪光：屏幕本身就是补光灯。
@MainActor
final class ScreenFlash {
    private var windows: [NSWindow] = []

    func on(_ screens: [NSScreen]) {
        for screen in screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.backgroundColor = .white
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.setFrame(screen.frame, display: false)
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }
        let current = windows
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.05
            for window in current {
                window.animator().alphaValue = 1
            }
        }
    }

    func off() {
        let current = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            for window in current {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for window in current {
                window.orderOut(nil)
            }
        })
    }
}
