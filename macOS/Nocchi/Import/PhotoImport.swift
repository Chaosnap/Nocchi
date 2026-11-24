import AppKit
import NocchiKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 从照片冲印：从「文件」或「照片」图库选图，每张用当前胶卷、相纸冲印成一张即显相片，从刘海逐张出片。
@MainActor
enum PhotoImport {
    /// 一次最多冲印几张。
    static let maxCount = 20

    /// 从文件选图（可以多选）。
    static func chooseFiles() {
        NotchController.shared.collapse()
        NSApp.activate()
        let model = AppModel.shared
        let panel = NSOpenPanel()
        panel.title = "冲印照片"
        panel.message = "选几张照片（最多 \(maxCount) 张），每张都会用「\(model.currentStock.name)」冲印成一张\(model.instantFormat.displayName)。"
        panel.prompt = "冲印"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        let urls = Array(panel.urls.prefix(maxCount))
        guard !urls.isEmpty else { return }
        Task {
            let images: [CGImage] = await Task.detached(priority: .userInitiated) {
                urls.compactMap { ImageIOKit.load($0, maxPixel: 3200) }
            }.value
            guard !images.isEmpty else {
                NotchController.shared.showToast("这些文件不是图片", symbol: "questionmark.circle.fill")
                return
            }
            await Darkroom.shared.developImported(images)
        }
    }

    /// 从「照片」图库选图：系统照片选择器只把选中的照片交给 Nocchi，不需要照片库权限。
    static func choosePhotosLibrary() {
        PhotoLibraryPickerWindow.shared.show()
    }
}

/// 放「照片」图库选择器的小窗口。
@MainActor
final class PhotoLibraryPickerWindow {
    static let shared = PhotoLibraryPickerWindow()

    private var window: NSWindow?

    private init() {}

    func show() {
        NotchController.shared.collapse()
        NSApp.activate()
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "从「照片」图库冲印"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PhotoLibraryPickerView(onDone: { [weak self] in
            self?.window?.close()
        }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

/// 「照片」图库选择器的内容：一张复古的冲印袋。
private struct PhotoLibraryPickerView: View {
    let onDone: () -> Void

    @ObservedObject private var model = AppModel.shared
    @State private var selection: [PhotosPickerItem] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 14) {
            FilmCanisterImage(stock: model.currentStock, size: 72)
                .padding(.top, 18)
            Text("从「照片」图库冲印")
                .font(RetroFont.serif(20, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("最多选 \(PhotoImport.maxCount) 张，每张都会用「\(model.currentStock.name)」冲印成\(model.instantFormat.displayName)，从刘海一张一张吐出来。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            PhotosPicker(selection: $selection, maxSelectionCount: PhotoImport.maxCount, matching: .images) {
                Label(isLoading ? "正在读取…" : "选择照片…", systemImage: "photo.stack")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Palette.terracotta))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 440, height: 320)
        .background(Palette.paper)
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            load(items)
        }
    }

    private func load(_ items: [PhotosPickerItem]) {
        isLoading = true
        Task {
            var images: [CGImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let image: CGImage? = await Task.detached(priority: .userInitiated) {
                    ImageIOKit.load(data: data, maxPixel: 3200)
                }.value
                if let image { images.append(image) }
            }
            isLoading = false
            selection = []
            onDone()
            guard !images.isEmpty else {
                NotchController.shared.showToast("没读到照片", symbol: "questionmark.circle.fill")
                return
            }
            await Darkroom.shared.developImported(images)
        }
    }
}
