import AppKit
import NocchiKit

/// 暗房：拍照 → 冲印 → 存档 → 从刘海出片。
@MainActor
final class Darkroom {
    static let shared = Darkroom()

    private var isShooting = false
    /// 大头贴机的屏幕快门正在一张一张框选。
    private var isFramingBooth = false

    private init() {}

    /// 大头贴机一条拍几格。
    private var boothFrames: Int { CameraBody.photoBooth.framesPerShot }

    // MARK: - Sources

    /// 屏幕快门（框选截图）。装着大头贴机时框选四次，拼成一条大头贴。
    func screenShutter() {
        guard !isShooting, !isFramingBooth else { return }
        NotchController.shared.collapse()
        if AppModel.shared.shootsBooth {
            Task { await boothScreenShutter() }
            return
        }
        Task {
            guard let image = await ScreenShutter.captureInteractive() else { return }
            Sound.play(.shutter)
            Haptics.heavy()
            await develop([image], source: .screen, body: .instant, mirror: false)
        }
    }

    /// 大头贴机的屏幕快门：框选四次（空格切换到整个窗口），每一格一张；中途按 Esc 就用已经框好的几张。
    private func boothScreenShutter() async {
        isFramingBooth = true
        defer { isFramingBooth = false }
        let total = boothFrames
        var frames: [CGImage] = []
        for index in 0..<total {
            if index > 0 {
                NotchController.shared.showToast("再框一张 · \(index + 1)/\(total)", symbol: "rectangle.dashed", duration: 1.6)
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            guard let image = await ScreenShutter.captureInteractive() else { break }
            frames.append(image)
            Sound.play(.shutterBooth)
            Haptics.heavy()
        }
        guard !frames.isEmpty else { return }
        await develop(Self.filled(frames, to: total), source: .screen, body: .photoBooth, mirror: false, booth: AppModel.shared.boothSetup())
    }

    /// 不够一条的格子按顺序循环补满（只有一张就是四张一样的，像一版证件照）。
    static func filled(_ frames: [CGImage], to count: Int) -> [CGImage] {
        guard !frames.isEmpty else { return [] }
        return (0..<max(count, frames.count)).map { frames[$0 % frames.count] }
    }

    /// 接管的系统截图。
    func developSystemScreenshot(at url: URL) {
        guard let image = ImageIOKit.load(url, maxPixel: 3200) else { return }
        Sound.play(.shutter)
        Task { await develop([image], source: .systemScreenshot, body: .instant, mirror: false) }
    }

    /// 从 Finder 拖到刘海上的图片：和「冲印照片」一样，即显相机一张一张冲，大头贴机每四张拼一条。
    func developDroppedFiles(at urls: [URL]) {
        let picked = Array(urls.prefix(PhotoImport.maxCount))
        guard !picked.isEmpty else { return }
        Task {
            let images: [CGImage] = await Task.detached(priority: .userInitiated) {
                picked.compactMap { ImageIOKit.load($0, maxPixel: 3200) }
            }.value
            guard !images.isEmpty else {
                NotchController.shared.showToast("这个文件不是图片", symbol: "questionmark.circle.fill")
                return
            }
            await developImported(images)
        }
    }

    /// 自拍：倒数 → 白屏补光 → 拍。装着大头贴机时连拍四张。
    func takeSelfie() async {
        if AppModel.shared.shootsBooth {
            await takeBoothSelfie()
            return
        }
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

    /// 刘海里的大头贴：取景器里连拍四张，每张前倒数、白屏闪光，拼成一条（不拉帘子的快速版）。
    private func takeBoothSelfie() async {
        let notch = NotchController.shared
        let camera = CameraService.shared
        let model = AppModel.shared
        let total = boothFrames
        var frames: [CGImage] = []
        defer { notch.boothShot = nil }
        for index in 0..<total {
            guard notch.mode == .selfie else { return }
            notch.boothShot = index + 1
            // 第一张照「自拍前倒数」的设置；之后每张都给两拍换个姿势。
            let counts = index == 0 ? (model.selfieCountdown ? [3, 2, 1] : []) : [2, 1]
            for n in counts {
                guard notch.mode == .selfie else { return }
                notch.countdown = n
                Sound.play(n == 1 ? .beepFinal : .beep)
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            notch.countdown = nil
            guard notch.mode == .selfie else { return }
            let flash = ScreenFlash()
            flash.on(NSScreen.screens)
            Sound.play(.shutterBooth)
            Haptics.heavy()
            try? await Task.sleep(nanoseconds: 90_000_000)
            let photo = try? await camera.capture(timeout: 4)
            flash.off()
            if let photo {
                frames.append(photo)
            }
            try? await Task.sleep(nanoseconds: 420_000_000)
        }
        notch.exitSelfie()
        guard !frames.isEmpty else {
            notch.showToast("大头贴没拍到，再来一次", symbol: "exclamationmark.triangle.fill")
            return
        }
        await develop(Self.filled(frames, to: total), source: .booth, body: .photoBooth, mirror: model.mirrorSelfie, booth: model.boothSetup())
    }

    /// 从照片冲印：一张一张来，等上一张出完片再出下一张，刘海不会同时吐两张。
    /// 装着大头贴机时每四张拼成一条大头贴（最后不够四张就循环补满）。
    func developImported(_ images: [CGImage]) async {
        let booth = AppModel.shared.shootsBooth
        let total = boothFrames
        let batches: [[CGImage]] = booth
            ? stride(from: 0, to: images.count, by: total).map { Self.filled(Array(images[$0..<min($0 + total, images.count)]), to: total) }
            : images.map { [$0] }
        for (index, batch) in batches.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
            }
            var waited = 0
            while (isShooting || NotchController.shared.mode == .ejecting), waited < 60 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                waited += 1
            }
            Sound.play(.shutter)
            if booth {
                await develop(batch, source: .library, body: .photoBooth, mirror: false, booth: AppModel.shared.boothSetup())
            } else {
                await develop(batch, source: .library, body: .instant, mirror: false)
            }
        }
    }

    // MARK: - Develop

    /// 冲印并出片。`booth` 是大头贴机「选相框」里选好的版式、相框和胶卷（其余来源传 nil）。
    func develop(_ images: [CGImage], source: PhotoSource, body: CameraBody, mirror: Bool, booth: BoothSetup? = nil) async {
        guard !images.isEmpty else { return }
        isShooting = true
        defer { isShooting = false }

        let model = AppModel.shared
        let stock: FilmStock
        if let booth {
            stock = model.stock(id: booth.stockID)
        } else if body == .photoBooth {
            stock = model.boothStock(monochrome: false)
        } else {
            stock = model.currentStock
        }
        let reloaded = model.consumeExposure(frames: images.count)
        let seed = SeededRandom.makeSeed()
        // 大头贴机用选好的版式；其余（自拍、屏幕快门、冲印照片）用你选的即显相纸。
        let format: FilmFormat = booth?.format ?? (body.format.isBooth ? body.format : model.instantFormat)
        let aspect = format.layout.windowAspect
        let bias = body.exposureBias
        let processor = Services.processor
        let library = Services.library

        var record = PhotoRecord(source: source, body: body, stock: stock, seed: seed, showsDate: model.printDate)
        record.format = format
        record.templateID = booth.map { TemplateCatalog.resolve(id: $0.templateID, format: format).id }
            ?? model.defaultTemplateID(for: format)
        record.captionFont = model.defaultCaptionFont
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
