import AppKit
import Carbon.HIToolbox
import SwiftUI

/// 设置与相册窗口（菜单栏 App 自己管理窗口，打开时把 App 提到前台）。
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?
    private var albumWindow: NSWindow?

    private init() {}

    func showSettings() {
        settingsWindow = present(settingsWindow, title: "Nocchi 设置", size: NSSize(width: 640, height: 560), autosave: "NocchiSettings") {
            SettingsView()
        }
    }

    /// 相册：透明标题栏 + 全尺寸内容，顶栏铺到最上面，红绿灯挪到顶栏中线上。
    func showAlbum() {
        albumWindow = present(
            albumWindow,
            title: "相册",
            size: NSSize(width: 1220, height: 820),
            minSize: NSSize(width: 980, height: 700),
            autosave: "NocchiAlbumV2",
            chromeless: true
        ) {
            AlbumView()
        }
    }

    private func present<Content: View>(
        _ existing: NSWindow?,
        title: String,
        size: NSSize,
        minSize: NSSize? = nil,
        autosave: String,
        chromeless: Bool = false,
        content: () -> Content
    ) -> NSWindow {
        NotchController.shared.collapse()
        if let existing {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            return existing
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if chromeless {
            style.insert(.fullSizeContentView)
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        if chromeless {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = NSColor(Palette.paper)
        }
        if let minSize {
            window.contentMinSize = minSize
        }
        window.contentView = NSHostingView(rootView: content().scrollIndicators(.never))
        window.center()
        window.setFrameAutosaveName(autosave)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        if chromeless {
            TrafficLights.attach(to: window, height: AlbumHeader.height, leading: 20)
        }
        return window
    }
}

/// 全局快捷键（Carbon，不需要辅助功能权限）。
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private var nextID: UInt32 = 1

    private init() {}

    func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E43_4849), id: id) // 'NCHI'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = action
        }
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    HotKeyCenter.shared.fire(id)
                }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// 默认快捷键：⌃⌥⌘S 屏幕快门、⌃⌥⌘F 自拍、⌃⌥⌘B 大头贴机。
@MainActor
enum HotKeys {
    static func registerDefaults() {
        let modifiers = controlKey | optionKey | cmdKey
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_S, modifiers: modifiers) {
            MainActor.assumeIsolated { Darkroom.shared.screenShutter() }
        }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_F, modifiers: modifiers) {
            MainActor.assumeIsolated {
                if NotchController.shared.mode == .selfie {
                    NotchController.shared.selfieShutter()
                } else {
                    NotchController.shared.enterSelfie()
                }
            }
        }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_B, modifiers: modifiers) {
            MainActor.assumeIsolated { PhotoBoothController.shared.start() }
        }
    }
}
