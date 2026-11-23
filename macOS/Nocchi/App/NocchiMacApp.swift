import AppKit
import NocchiKit
import SwiftUI

/// Nocchi for macOS：住在菜单栏里的相机铺，出片口是刘海。
@main
struct NocchiMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "camera.aperture")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel.shared
        model.applyRuntimeSettings()
        SoundPlayer.shared.preload()

        NotchController.shared.install()
        HotKeys.registerDefaults()
        LibraryStore.shared.reload()
        NotchShelf.shared.load()
        DesktopBoard.shared.restore()

        ScreenshotWatcher.shared.setEnabled(model.takeOverScreenshots)
        model.onTakeOverChange = { enabled in
            ScreenshotWatcher.shared.setEnabled(enabled)
        }

        if !model.hasSeenWelcome {
            model.hasSeenWelcome = true
            NotchController.shared.showToast("把鼠标移到刘海上试试", symbol: "hand.point.up.left.fill", duration: 4)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DesktopBoard.shared.persistAll()
    }
}
