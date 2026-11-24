import AppKit
import NocchiKit
import NocchiUI
import SwiftUI

/// 截图工作室：只在 GitHub Actions 上用，给 README 和产品文档拍截图。
///
/// `Nocchi --render-screenshots <目录>` 启动时不开刘海、不注册快捷键。先用仓库里的原创样片
/// （`design/screenshots/samples`，由环境变量 `NOCCHI_SCREENSHOT_SAMPLES` 指定）在临时照片库
/// （`NOCCHI_LIBRARY_ROOT`）里冲印一批照片，然后：
/// - 打开真实的相册（四种看法）、装饰台、设置窗口，向窗口服务器要自己窗口的画面（自己的窗口不需要
///   屏幕录制权限；拿不到时退回 `cacheDisplay`），放到桌面壁纸上；
/// - 用 `ImageRenderer` 以 2 倍像素合成「刘海出片 + 照片堆」的桌面、相纸一览和大头贴的「选相框」。
/// 每张图写成 JPEG，`manifest.json` 记下尺寸和拍法；标准输出里以 `SHOT` / `STUDIO` 开头的行会被工作流写成注解。
@MainActor
enum ScreenshotStudio {
    /// `--render-screenshots <目录>`；没有这个参数时为 nil（正常启动）。
    static var requestedOutput: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--render-screenshots"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    static func run(to output: URL) {
        NSApp.setActivationPolicy(.regular)
        let studio = Studio(output: output)
        // 看门狗：无论卡在哪里，8 分钟后都退出，工作流不会白等。
        DispatchQueue.main.asyncAfter(deadline: .now() + 480) {
            print("STUDIO watchdog: still running after 8 minutes, quitting")
            fflush(stdout)
            exit(3)
        }
        Task { @MainActor in
            await studio.run()
            NSApp.terminate(nil)
        }
    }
}

/// 冲印好的一张样片（记录 + 底片 + 胶卷相纸），给合成场景用。
struct StudioPrint {
    var record: PhotoRecord
    var images: [CGImage]
    var paper: PaperStyle
}

@MainActor
private final class Studio {
    let output: URL
    private var manifest: [[String: Any]] = []
    private var prints: [String: StudioPrint] = [:]

    init(output: URL) {
        self.output = output
    }

    func run() async {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let screen = NSScreen.main
        say("STUDIO screen=\(Int(screen?.frame.width ?? 0))x\(Int(screen?.frame.height ?? 0)) scale=\(screen?.backingScaleFactor ?? 0) library=\(Services.library.root.path)")
        configureModel()

        let samples = SampleShelf.load()
        say("STUDIO samples=\(samples.count) [\(samples.keys.sorted().joined(separator: ","))]")
        guard !samples.isEmpty else {
            writeManifest()
            return
        }
        prints = await develop(samples)
        say("STUDIO developed=\(prints.count)")
        LibraryStore.shared.reload()
        await pause(1.5)

        await renderComposites()
        await captureAlbum()
        await captureDecorateDesk()
        await captureSettings()
        await captureNotch()
        writeManifest()
        say("STUDIO done shots=\(manifest.count)")
    }

    // MARK: - 准备

    private func configureModel() {
        let model = AppModel.shared
        model.quietMode = true
        model.printDate = true
        model.defaultCaption = PhotoRecord.defaultCaption
        model.instantFormat = .instantSquare
        model.boothFormat = .boothStrip
        model.boothMonochrome = false
        model.defaultBoothTemplateID = TemplateCatalog.defaultBoothID
        model.defaultCaptionFont = .handwriting
        AlbumRouter.shared.mode = .cork
    }

    private func develop(_ samples: [String: CGImage]) async -> [String: StudioPrint] {
        let library = Services.library
        let processor = Services.processor
        let now = Date()
        var result: [String: StudioPrint] = [:]
        for spec in StudioSpecs.all {
            guard let source = samples[spec.sample] else {
                say("STUDIO missing sample \(spec.sample)")
                continue
            }
            let frames = spec.format.isBooth ? SampleShelf.boothFrames(from: source) : [source]
            let developed = await Task.detached(priority: .userInitiated) {
                StudioSpecs.develop(spec, frames: frames, library: library, processor: processor, now: now)
            }.value
            if let developed {
                result[spec.key] = developed
            } else {
                say("STUDIO failed to develop \(spec.key)")
            }
        }
        return result
    }

    // MARK: - 合成场景（2 倍像素）

    private func renderComposites() async {
        render("desk", size: DeskScene.size, DeskScene(prints: prints))
        render("prints", size: CGSize(width: 1600, height: 1000), PrintGalleryScene(prints: prints))

        let booth = PhotoBoothController.shared
        booth.showcaseFrameChooser()
        await booth.previews.prefetch(booth.prefetchRequests())
        await pause(0.3)
        let boothSize = CGSize(width: 1300, height: 1100)
        let velvet = CurtainScene().renderClosed(size: boothSize, gap: 780)
        say("SHOT curtain=\(velvet == nil ? "flat-fallback" : "scenekit")")
        render("booth", size: boothSize, BoothScene(booth: booth, curtain: velvet, size: boothSize))
        booth.endShowcase()
    }

    private func render<V: View>(_ name: String, size: CGSize, _ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
        renderer.scale = 2
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            say("SHOT name=\(name) failed=image-renderer")
            return
        }
        save(image, name: name, method: "image-renderer@2x")
    }

    // MARK: - 真实窗口

    private func captureAlbum() async {
        WindowManager.shared.showAlbum()
        await pause(1.0)
        let views: [(AlbumMode, String)] = [(.cork, "album-corkboard"), (.cardBox, "album-cardbox"), (.film, "album-film"), (.calendar, "album-calendar")]
        for (mode, name) in views {
            AlbumRouter.shared.mode = mode
            await capture(name, title: "相册", size: CGSize(width: 1220, height: 820), settle: mode == .cardBox ? 4.0 : 2.5)
        }
        window(titled: "相册")?.close()
    }

    private func captureDecorateDesk() async {
        guard let latte = prints["latte"] else { return }
        DecorateDesk.shared.open(latte.record)
        await capture("decorate", title: "装饰台", size: CGSize(width: 1180, height: 800), settle: 3.5)
        DecorateDesk.shared.close()
    }

    private func captureSettings() async {
        WindowManager.shared.showSettings()
        await capture("settings", title: "Nocchi 设置", size: nil, settle: 2.0)
        window(titled: "Nocchi 设置")?.close()
    }

    /// 真的刘海面板：悬停面板和胶卷柜（面板窗口是透明的，叠到壁纸 + 菜单栏上）。
    private func captureNotch() async {
        let notch = NotchController.shared
        notch.install()
        await pause(1.0)
        let panels: [(NotchMode, String)] = [(.hover, "notch-panel"), (.films, "film-cabinet")]
        for (mode, name) in panels {
            notch.showcase(mode)
            await pause(1.8)
            guard let panel = notch.panelWindow else {
                say("SHOT name=\(name) failed=no-panel")
                continue
            }
            var candidates: [(method: String, image: CGImage, spread: Double)] = []
            if let image = WindowGrab.windowServer(panel) {
                candidates.append(("window-server", image, ImageStats.spread(image)))
            }
            if let image = WindowGrab.cacheDisplay(panel) {
                candidates.append(("cache-display", image, ImageStats.spread(image)))
            }
            let summary = candidates.map { "\($0.method)=\($0.image.width)x\($0.image.height)/σ\(Int($0.spread))" }.joined(separator: " ")
            guard let best = candidates.first(where: { $0.spread > 3 }) ?? candidates.max(by: { $0.spread < $1.spread }) else {
                say("SHOT name=\(name) failed=no-capture")
                continue
            }
            let scale = max(1, CGFloat(best.image.width) / max(panel.frame.width, 1))
            let composed = WindowGrab.onNotchBackdrop(best.image, scale: scale) ?? best.image
            save(composed, name: name, method: best.method, note: summary)
        }
        notch.showcase(.idle)
    }

    private func window(titled title: String) -> NSWindow? {
        NSApp.windows.first { $0.title == title && $0.isVisible }
    }

    private func capture(_ name: String, title: String, size: CGSize?, settle: Double) async {
        var found = window(titled: title)
        var waited = 0.0
        while found == nil, waited < 6 {
            await pause(0.25)
            waited += 0.25
            found = window(titled: title)
        }
        guard let window = found else {
            say("SHOT name=\(name) failed=no-window title=\(title)")
            return
        }
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frameSize = size ?? window.frame.size
        window.setFrame(NSRect(x: screenFrame.minX + 16, y: screenFrame.maxY - frameSize.height - 16, width: frameSize.width, height: frameSize.height), display: true)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        await pause(settle)

        var candidates: [(method: String, image: CGImage, spread: Double)] = []
        if let image = WindowGrab.windowServer(window) {
            candidates.append(("window-server", image, ImageStats.spread(image)))
        }
        if let image = WindowGrab.cacheDisplay(window) {
            candidates.append(("cache-display", image, ImageStats.spread(image)))
        }
        let summary = candidates.map { "\($0.method)=\($0.image.width)x\($0.image.height)/σ\(Int($0.spread))" }.joined(separator: " ")
        guard let best = candidates.first(where: { $0.spread > 6 }) ?? candidates.max(by: { $0.spread < $1.spread }) else {
            say("SHOT name=\(name) failed=no-capture")
            return
        }
        let scale = max(1, CGFloat(best.image.width) / max(window.frame.width, 1))
        let framed = WindowGrab.onWallpaper(best.image, scale: scale) ?? best.image
        save(framed, name: name, method: best.method, note: summary)
    }

    // MARK: - 输出

    private func save(_ image: CGImage, name: String, method: String, note: String = "") {
        let url = output.appendingPathComponent("\(name).jpg")
        do {
            try ImageIOKit.writeJPEG(image, to: url, quality: 0.86)
            let spread = ImageStats.spread(image)
            manifest.append(["name": name, "width": image.width, "height": image.height, "method": method, "spread": spread, "note": note])
            say("SHOT name=\(name) size=\(image.width)x\(image.height) method=\(method) spread=\(Int(spread)) \(note)")
        } catch {
            say("SHOT name=\(name) failed=write \(error.localizedDescription)")
        }
    }

    private func writeManifest() {
        let url = output.appendingPathComponent("manifest.json")
        if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }

    private func say(_ line: String) {
        print(line)
        fflush(stdout)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - 样片

/// 仓库里的原创样片（Codex 生成，见 `docs/ASSETS.md`）。
enum SampleShelf {
    static func load() -> [String: CGImage] {
        guard let path = ProcessInfo.processInfo.environment["NOCCHI_SCREENSHOT_SAMPLES"], !path.isEmpty else { return [:] }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var samples: [String: CGImage] = [:]
        for file in files where ["jpg", "jpeg", "png"].contains(file.pathExtension.lowercased()) {
            let name = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "sample-", with: "")
            if let image = ImageIOKit.load(file, maxPixel: 1600) {
                samples[name] = image
            }
        }
        return samples
    }

    /// 大头贴样片是一张 2 × 2 的四连拍：切成四格（往里收一点，避开中间的缝）。
    static func boothFrames(from image: CGImage) -> [CGImage] {
        let width = CGFloat(image.width) / 2
        let height = CGFloat(image.height) / 2
        let inset = min(width, height) * 0.04
        var frames: [CGImage] = []
        for row in 0..<2 {
            for column in 0..<2 {
                let rect = CGRect(x: CGFloat(column) * width + inset, y: CGFloat(row) * height + inset, width: width - 2 * inset, height: height - 2 * inset).integral
                if let frame = image.cropping(to: rect) {
                    frames.append(frame)
                }
            }
        }
        return frames.count == 4 ? frames : [image, image, image, image]
    }
}

// MARK: - 统计与截窗

enum ImageStats {
    /// 缩到 32 × 32 灰度后的标准差：几乎是纯色（截到空白）时很小。
    static func spread(_ image: CGImage) -> Double {
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return 0 }
        let values = pixels.map(Double.init)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}

@MainActor
enum WindowGrab {
    private typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> UnsafeRawPointer?

    /// `CGWindowListCreateImage`（macOS 14 起标为弃用，这里按名字动态取，免得编译器拦着）。
    private static let createImage: CreateImage? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CreateImage.self)
    }()

    /// 向窗口服务器要自己窗口的画面（不含窗口阴影）。自己的窗口不需要屏幕录制权限。
    static func windowServer(_ window: NSWindow) -> CGImage? {
        guard let createImage, window.windowNumber > 0 else { return nil }
        let includingWindow: UInt32 = 1 << 3
        let ignoreFraming: UInt32 = 1 << 0
        let bestResolution: UInt32 = 1 << 3
        guard let raw = createImage(.null, includingWindow, UInt32(window.windowNumber), ignoreFraming | bestResolution) else { return nil }
        return Unmanaged<CGImage>.fromOpaque(raw).takeRetainedValue()
    }

    /// 让视图自己画一遍（包括标题栏所在的整个窗口框）。
    static func cacheDisplay(_ window: NSWindow) -> CGImage? {
        guard let view = window.contentView?.superview ?? window.contentView else { return nil }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0, let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        return rep.cgImage
    }

    /// 刘海面板叠到壁纸 + 菜单栏上：只留黑色的岛和四周一圈桌面（面板窗口本身比岛大得多，大部分是透明的）。
    static func onNotchBackdrop(_ panel: CGImage, scale: CGFloat) -> CGImage? {
        let bounds = opaqueBounds(panel) ?? CGRect(x: 0, y: 0, width: panel.width, height: panel.height)
        let margin = 64 * scale
        let left = max(0, bounds.minX - margin)
        let right = min(CGFloat(panel.width), bounds.maxX + margin)
        let width = (right - left).rounded()
        let height = (bounds.maxY + 72 * scale).rounded()
        guard width > 0, height > 0 else { return nil }
        let renderer = ImageRenderer(content: NotchBackdrop(width: width / scale, height: height / scale))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let backdrop = renderer.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.draw(backdrop, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(panel, in: CGRect(x: -left, y: height - CGFloat(panel.height), width: CGFloat(panel.width), height: CGFloat(panel.height)))
        return context.makeImage()
    }

    /// 不透明部分的外框（像素，原点左上）。
    static func opaqueBounds(_ image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { buffer -> CGRect? in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                let row = y * width * 4
                for x in 0..<width where buffer[row + x * 4 + 3] > 12 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }

    /// 把窗口放到 Nocchi 的桌面壁纸上：四周留白、加一层柔和的投影。
    static func onWallpaper(_ window: CGImage, scale: CGFloat) -> CGImage? {
        let padding = 56 * scale
        let width = CGFloat(window.width) + 2 * padding
        let height = CGFloat(window.height) + 2 * padding
        let renderer = ImageRenderer(content: StudioWallpaper().frame(width: width / scale, height: height / scale))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let wallpaper = renderer.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(wallpaper, in: full)
        let frame = CGRect(x: padding, y: padding, width: CGFloat(window.width), height: CGFloat(window.height))
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -14 * scale), blur: 40 * scale, color: CGColor(gray: 0, alpha: 0.45))
        context.draw(window, in: frame)
        context.restoreGState()
        context.draw(window, in: frame)
        return context.makeImage()
    }
}
