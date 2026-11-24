import AppKit
import NocchiKit

/// 暗房：拍照 → 冲印 → 存档 → 从刘海出片。
@MainActor
final class Darkroom {
    static let shared = Darkroom()

    private var isShooting = false

    private init() {}

    // MARK: - Sources

    /// 屏幕快门（框选截图）。
    func screenShutter() {
        guard !isShooting else { return }
        NotchController.shared.collapse()
        Task {
            guard let image = await ScreenShutter.captureInteractive() else { return }
            Sound.play(.shutter)
            Haptics.heavy()
            await develop([image], source: .screen, body: .instant, mirror: false)
        }
    }

    /// 接管的系统截图。
    func developSystemScreenshot(at url: URL) {
        guard let image = ImageIOKit.load(url, maxPixel: 3200) else { return }
        Sound.play(.shutter)
        Task { await develop([image], source: .systemScreenshot, body: .instant, mirror: false) }
    }

    /// 从 Finder 拖到刘海上的图片：冲印成拍立得。
    func developDroppedFile(at url: URL) {
        guard let image = ImageIOKit.load(url, maxPixel: 3200) else {
            NotchController.shared.showToast("这个文件不是图片", symbol: "questionmark.circle.fill")
            return
        }
        Sound.play(.shutter)
        Task { await develop([image], source: .library, body: .instant, mirror: false) }
    }

    /// 自拍：倒数 → 白屏补光 → 拍。
    func takeSelfie() async {
        let notch = NotchController.shared
        let camera = CameraService.shared
        if AppModel.shared.selfieCountdown {
            for n in [3, 2, 1] {
                guard notch.mode == .selfie else { return }
                notch.countdown = n
                Sound.play(n == 1 ? .beepFinal : .beep)
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            notch.countdown = nil
        }
        guard notch.mode == .selfie else { return }
        let flash = ScreenFlash()
        flash.on(NSScreen.screens)
        Sound.play(.shutter)
        Haptics.heavy()
        try? await Task.sleep(nanoseconds: 90_000_000)
        // capture 自带超时：无论如何闪光都会撤掉。
        let photo = try? await camera.capture(timeout: 4)
        flash.off()
        notch.exitSelfie()
        guard let photo else {
            notch.showToast("没拍到，再试一次", symbol: "exclamationmark.triangle.fill")
            return
        }
        await develop([photo], source: .selfie, body: .instant, mirror: AppModel.shared.mirrorSelfie)
    }

    /// 从照片冲印：一张一张来，等上一张出完片再出下一张，刘海不会同时吐两张。
    func developImported(_ images: [CGImage]) async {
        for (index, image) in images.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
            }
            var waited = 0
            while (isShooting || NotchController.shared.mode == .ejecting), waited < 60 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                waited += 1
            }
            Sound.play(.shutter)
            await develop([image], source: .library, body: .instant, mirror: false)
        }
    }

    // MARK: - Develop

    /// 冲印并出片。
    func develop(_ images: [CGImage], source: PhotoSource, body: CameraBody, mirror: Bool) async {
        guard !images.isEmpty else { return }
        isShooting = true
        defer { isShooting = false }

        let model = AppModel.shared
        let stock = body == .photoBooth && model.currentStock.id == FilmCatalog.defaultStock.id
            ? model.stock(id: body.defaultStockID)
            : model.currentStock
        let reloaded = model.consumeExposure(frames: images.count)
        let seed = SeededRandom.makeSeed()
        // 大头贴机用它自己的版式；其余（自拍、屏幕快门、冲印照片）用你选的即显相纸。
        let format: FilmFormat = body.format.isBooth ? body.format : model.instantFormat
        let aspect = format.layout.windowAspect
        let bias = body.exposureBias
        let processor = Services.processor
        let library = Services.library

        var record = PhotoRecord(source: source, body: body, stock: stock, seed: seed, showsDate: model.printDate)
        record.format = format
        let caption = model.defaultCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        record.caption = caption.isEmpty ? nil : caption
        if body == .photoBooth {
            record.frameOffsets = PhotoRecord.makeFrameOffsets(count: images.count, seed: seed, amount: 0.012)
        }
        let recordID = record.id

        let result: (negatives: [CGImage], names: [String]) = await Task.detached(priority: .userInitiated) {
            var negatives: [CGImage] = []
            var names: [String] = []
            for (index, image) in images.enumerated() {
                let focus = SmartCrop.focusPoint(in: image)
                let options = ProcessOptions(
                    targetAspect: aspect,
                    focus: focus,
                    maxLongEdge: 1600,
                    mirror: mirror,
                    seed: seed &+ UInt64(index),
                    exposureBias: bias
                )
                guard let negative = processor.process(image, stock: stock, options: options) else { continue }
                negatives.append(negative)
                if let name = try? library.writeNegative(negative, recordID: recordID, index: index) {
                    names.append(name)
                }
            }
            return (negatives, names)
        }.value

        guard !result.negatives.isEmpty else {
            NotchController.shared.showToast("冲洗失败了", symbol: "exclamationmark.triangle.fill")
            return
        }
        record.negatives = result.names
        record.desk = DeskPlacement(x: 0, y: 0, rotation: PhotoRecord.randomTilt(seed: seed), layer: model.defaultLayer)
        try? library.save(record)
        LibraryStore.shared.upsert(record)

        DesktopBoard.shared.eject(record: record, negatives: result.negatives, stock: stock)
        if reloaded {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                Sound.play(.gearClick)
                NotchController.shared.showToast("这一卷拍完了，换上新的 \(stock.name)", symbol: "film.stack")
            }
        }
    }
}
