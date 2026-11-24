import AppKit
import NocchiKit
import SwiftUI

/// Nocchi for macOS：住在刘海里的相机铺。默认是普通 App（程序坞图标 + 主菜单），
/// 设置里可以改成只住在菜单栏和刘海里。
@main
struct NocchiMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 界面语言要在查任何翻译之前定下来（默认中文）。
        AppLanguage.applyAtLaunch()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "camera.aperture")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            NocchiCommands()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 用户导入的字体只在本进程注册：每次启动先注册，装饰台和成片才认得它们。
        Services.fonts.registerAll()
        // 自定义贴纸的图由照片库提供：成片、桌面上的相纸、装饰台都靠它画「我的贴纸」。
        StickerArt.customProvider = { Services.stickers.art(forKindID: $0) }
        // GitHub Actions 上的截图工作室：不开刘海、不注册快捷键，拍完截图就退出。
        if let output = ScreenshotStudio.requestedOutput {
            ScreenshotStudio.run(to: output)
            return
        }
        let model = AppModel.shared
        model.applyRuntimeSettings()
        SoundPlayer.shared.preload()
        CameraService.shared.setPreferredDevice(model.cameraDeviceID)

        NotchController.shared.install()
        HotKeys.registerDefaults()
        LibraryStore.shared.reload()
        NotchShelf.shared.load()
        DesktopBoard.shared.restore()

        ScreenshotWatcher.shared.setEnabled(model.takeOverScreenshots)
        model.onTakeOverChange = { enabled in
            ScreenshotWatcher.shared.setEnabled(enabled)
        }

        // 每次启动：刘海像灵动岛一样轻轻「醒」一下；第一次启动再教一下怎么用。
        NotchController.shared.greet(firstLaunch: !model.hasSeenWelcome)
        model.hasSeenWelcome = true

        // 打开就是相册的卡片盒（设置 → 程序里可以关）；等刘海的问候亮完再开窗口。
        if model.openAlbumOnLaunch {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                AlbumRouter.shared.show(.cardBox)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DesktopBoard.shared.persistAll()
    }

    /// 点程序坞图标：没有打开的窗口时打开相册。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showAlbum()
        }
        return true
    }

    /// 关掉最后一个窗口也不退出：相机铺还在刘海里营业。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 程序坞图标的右键菜单。
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        item(String(localized: "屏幕快门"), #selector(dockScreenShutter))
        item(String(localized: "自拍"), #selector(dockSelfie))
        item(String(localized: "大头贴机"), #selector(dockBooth))
        menu.addItem(.separator())
        item(String(localized: "冲印照片…"), #selector(dockImportFiles))
        item(String(localized: "从「照片」图库冲印…"), #selector(dockImportLibrary))
        menu.addItem(.separator())
        item(String(localized: "打开相册"), #selector(dockAlbum))
        return menu
    }

    @objc private func dockScreenShutter() { Darkroom.shared.screenShutter() }
    @objc private func dockSelfie() { NotchController.shared.enterSelfie() }
    @objc private func dockBooth() { PhotoBoothController.shared.start() }
    @objc private func dockImportFiles() { PhotoImport.chooseFiles() }
    @objc private func dockImportLibrary() { PhotoImport.choosePhotosLibrary() }
    @objc private func dockAlbum() { WindowManager.shared.showAlbum() }
}

/// 主菜单（App 在前台时出现在屏幕顶端）。
struct NocchiCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") { WindowManager.shared.showSettings() }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandMenu(String(localized: "相机")) {
            Button("屏幕快门") { Darkroom.shared.screenShutter() }
                .keyboardShortcut("s", modifiers: [.control, .option, .command])
            Button("自拍") { NotchController.shared.enterSelfie() }
                .keyboardShortcut("f", modifiers: [.control, .option, .command])
            Button("大头贴机") { PhotoBoothController.shared.start() }
                .keyboardShortcut("b", modifiers: [.control, .option, .command])
            Divider()
            Button("冲印照片…") { PhotoImport.chooseFiles() }
                .keyboardShortcut("o", modifiers: .command)
            Button("从「照片」图库冲印…") { PhotoImport.choosePhotosLibrary() }
                .keyboardShortcut("o", modifiers: [.shift, .command])
        }
        CommandMenu(String(localized: "相册")) {
            Button("打开相册") { WindowManager.shared.showAlbum() }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            ForEach(AlbumMode.allCases) { mode in
                Button(mode.title) { AlbumRouter.shared.show(mode) }
                    .keyboardShortcut(mode.key, modifiers: .command)
            }
            Button("搜索照片…") { AlbumRouter.shared.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
            Divider()
            Button("收起桌面上的照片") { DesktopBoard.shared.collectAll() }
            Button("在 Finder 中打开照片文件夹") {
                NSWorkspace.shared.open(Services.library.printsRoot)
            }
        }
    }
}
