import AppKit
import NocchiKit
import SwiftUI
import UniformTypeIdentifiers

/// 「我的贴纸」：导入自己的图片做成贴纸，并能重命名、换模切边、排序、删掉。
///
/// 数据在 NocchiKit 的 `CustomStickerStore`（照片库 `stickers/`）；这里只是给界面用的可观察外壳。
/// 删掉只是从贴纸库里拿掉，已经贴在照片上的照样画得出来。
@MainActor
final class StickerShelf: ObservableObject {
    static let shared = StickerShelf()

    @Published private(set) var stickers: [CustomSticker] = Services.stickers.stickers
    @Published private(set) var message: String?

    private init() {}

    /// 导入图片文件（PNG / JPG / HEIC / TIFF……），返回做好的贴纸。
    @discardableResult
    func importFiles(_ urls: [URL]) -> [CustomSticker] {
        var added: [CustomSticker] = []
        var failed = 0
        for url in urls {
            if let sticker = try? Services.stickers.importImage(at: url) {
                added.append(sticker)
            } else {
                failed += 1
            }
        }
        refresh()
        if failed > 0 {
            message = "有 \(failed) 个文件读不出图片"
        } else if !added.isEmpty {
            message = "做好了 \(added.count) 枚贴纸"
            SoundPlayer.shared.play(.cardSlide)
        }
        return added
    }

    func importWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "选几张图片做成贴纸（透明背景的 PNG 效果最好）"
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls)
    }

    func rename(_ sticker: CustomSticker) {
        let alert = NSAlert()
        alert.messageText = "给贴纸起个名字"
        let field = NSTextField(string: sticker.name)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Services.stickers.rename(sticker.id, to: field.stringValue)
        refresh()
    }

    func toggleDieCut(_ sticker: CustomSticker) {
        Services.stickers.setDieCut(sticker.id, !sticker.dieCut)
        refresh()
    }

    func move(_ sticker: CustomSticker, by offset: Int) {
        Services.stickers.move(sticker.id, by: offset)
        refresh()
    }

    func remove(_ sticker: CustomSticker) {
        Services.stickers.remove(sticker.id)
        refresh()
        message = "已从贴纸库拿掉（已经贴在照片上的不会消失）"
    }

    private func refresh() {
        stickers = Services.stickers.stickers
        StickerImageCache.shared.removeAll()
    }
}
