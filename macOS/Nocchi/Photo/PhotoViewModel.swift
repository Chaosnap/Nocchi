import AppKit
import Combine
import NocchiKit
import QuartzCore
import SwiftUI

/// 一张桌面照片的状态：底片、显影进度、出片进度、倾斜、手写。
@MainActor
final class PhotoViewModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var record: PhotoRecord
    let negatives: [CGImage]
    /// 叠加了色块的底片（界面与成片都用它）。
    @Published private(set) var displayImages: [CGImage]
    /// 0 = 还在出片口里，1 = 完全出来。
    @Published var ejectProgress: CGFloat = 1
    /// 出片时只露出出片口下沿以下的部分。
    @Published var masking = false
    @Published var tilt: Double = 0
    @Published var lifted = false
    @Published var penMode = false
    @Published var liveStroke: InkStroke?
    /// 光面高光位置（0…1），随相片在屏幕上的位置移动。
    @Published var sheen = CGPoint(x: 0.32, y: 0.22)
    /// 出片时挂在出片口上的摆动（度，绕出片口转）。
    @Published var ejectSway: Double = 0
    /// 出片时滚轮推一下的左右小抖动（点）。
    @Published var ejectJitter: CGFloat = 0
    @Published private(set) var developments: [DevelopmentModel]
    /// 出片完成后才开始显影。
    var developingStarted = false

    let paper: PaperStyle
    let paperWidth: CGFloat

    /// 窗口四周给阴影和倾斜留的空间。
    static let padding: CGFloat = 34

    init(record: PhotoRecord, negatives: [CGImage], paper: PaperStyle, developed: Bool, developSeconds: Double) {
        id = record.id
        self.record = record
        self.negatives = negatives
        displayImages = negatives
        self.paper = paper
        paperWidth = record.format.defaultDisplayWidth
        let isBooth = record.body == .photoBooth
        let base = isBooth ? record.body.developDuration : developSeconds
        developments = negatives.indices.map { index in
            var model = DevelopmentModel(baseDuration: base, startDelay: isBooth ? Double(index) * 1.4 : 0)
            if developed { model.complete() }
            return model
        }
    }

    var layout: PaperLayout { record.layout }
    var paperSize: CGSize { layout.size(forWidth: paperWidth) }
    var windowSize: CGSize {
        CGSize(width: paperSize.width + 2 * Self.padding, height: paperSize.height + 2 * Self.padding)
    }

    var isDeveloped: Bool { developments.allSatisfy(\.isComplete) }

    func image(at index: Int) -> CGImage? {
        index < displayImages.count ? displayImages[index] : nil
    }

    func visual(at index: Int) -> DevelopmentVisual {
        index < developments.count ? DevelopmentVisual.at(developments[index].progress) : .developed
    }

    func frameOffset(_ index: Int) -> FrameOffset {
        index < record.frameOffsets.count ? record.frameOffsets[index] : .zero
    }

    /// 推进显影；返回 true 表示这一下刚好显影完成。
    func tick(_ dt: TimeInterval) -> Bool {
        guard developingStarted, !isDeveloped else { return false }
        for index in developments.indices {
            developments[index].advance(by: dt)
        }
        return isDeveloped
    }

    func shake(energy: Double) {
        for index in developments.indices {
            developments[index].addShake(energy: energy)
        }
    }

    func setDisplayImages(_ images: [CGImage]) {
        displayImages = images
    }
}

/// 60 Hz 的主线程计时器（拖动、菜单追踪时也不停）。
@MainActor
final class FrameTicker {
    private var timer: Timer?
    private var last: CFTimeInterval = 0
    private let handler: (TimeInterval) -> Bool

    /// handler 返回 false 时停止。
    init(_ handler: @escaping (TimeInterval) -> Bool) {
        self.handler = handler
    }

    var isRunning: Bool { timer != nil }

    func start() {
        stop()
        last = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                let now = CACurrentMediaTime()
                let dt = min(0.1, now - self.last)
                self.last = now
                if !self.handler(dt) {
                    self.stop()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
