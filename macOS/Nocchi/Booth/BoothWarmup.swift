import AppKit
import NocchiKit
import SwiftUI

/// 启动后在后台把大头贴机准备好。
///
/// 所有者：「booth entry 只有第一次启动时会卡，能不能在进入软件后在后台准备」。第一次拉帘子时要做的重活都是一次性的：
/// SceneKit 编译布帘的着色器、上传丝绒纹理，解码整机（1440 × 1920）和零件的大图，合成橱窗里的样张，合成拉帘、投币的声音。
/// 这些都挪到启动后几秒、在后台线程做掉；准备好的东西留着，之后每次进大头贴机都直接用。看到的画面完全一样。
@MainActor
enum BoothWarmup {
    private static var started = false

    /// 启动后过一会儿再准备（等相册窗口、刘海的问候先出来）。
    static func schedule(after delay: TimeInterval = 2.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated { start() }
        }
    }

    static func start() {
        guard !started else { return }
        started = true
        let booth = PhotoBoothController.shared
        guard !booth.isActive else { return }
        SoundPlayer.shared.preload([.curtain, .coin, .gearClick, .magnet, .shutterBooth, .beep, .beepFinal])
        if BoothMachine.isAvailable {
            BoothArt.prewarm([BoothMachine.baseImage] + BoothArt.parts)
        }
        booth.prepareCurtain()
        Task(priority: .utility) {
            await booth.prewarmPreviews()
        }
    }
}

/// 大头贴机的渲染图：解码好的位图留在内存里，画的时候直接用（缺了就照常从素材目录读）。
enum BoothArt {
    /// 控制台上的零件图（箭头、拨杆、开始按钮的各个状态）。
    static let parts = [
        "BoothMachineArrowLeft", "BoothMachineArrowLeftDown", "BoothMachineArrowRight", "BoothMachineArrowRightDown",
        "BoothMachineFormatLeft", "BoothMachineFormatRight", "BoothMachineColorLeft", "BoothMachineColorRight",
        "BoothMachineStart", "BoothMachineStartDown", "BoothMachineStartLit",
    ]

    /// 这张图：解码好的位图，或者素材目录里的原图。都是 `.resizable()` 地画，像素一样。
    static func image(_ name: String) -> Image {
        if let decoded = BoothArtCache.shared.image(named: name) {
            return Image(decorative: decoded, scale: 2)
        }
        return Image(name)
    }

    /// 在后台线程解码（主线程只取出图，不解码）。
    @MainActor
    static func prewarm(_ names: [String]) {
        var sources: [(String, CGImage)] = []
        for name in names where BoothArtCache.shared.image(named: name) == nil {
            guard let image = NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            sources.append((name, image))
        }
        guard !sources.isEmpty else { return }
        Task.detached(priority: .utility) {
            for (name, image) in sources {
                if let decoded = decode(image) {
                    BoothArtCache.shared.store(decoded, named: name)
                }
            }
        }
    }

    /// 画进同样大小、同样色彩空间的位图里：得到一张已经解码好的图（之后画它不再解码）。
    static func decode(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let space,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

/// 解码好的大头贴机图（线程安全）。
final class BoothArtCache: @unchecked Sendable {
    static let shared = BoothArtCache()

    private let lock = NSLock()
    private var images: [String: CGImage] = [:]

    func image(named name: String) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return images[name]
    }

    func store(_ image: CGImage, named name: String) {
        lock.lock()
        images[name] = image
        lock.unlock()
    }
}
