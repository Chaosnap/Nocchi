import AVFoundation
import Foundation

/// 用 AVAudioEngine 播放合成音效。四个播放节点轮流使用，声音可以叠在一起。
public final class SoundPlayer: @unchecked Sendable {
    public static let shared = SoundPlayer()

    /// 安静模式：完全不出声。
    public var isMuted = false

    /// 主音量 0…1。
    public var volume: Float = 0.8 {
        didSet {
            let v = volume
            queue.async { self.engine.mainMixerNode.outputVolume = v }
        }
    }

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var nextNode = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private let format: AVAudioFormat?
    private let queue = DispatchQueue(label: "app.nocchi.sound", qos: .userInitiated)

    public init() {
        format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)
        guard let format else { return }
        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        engine.mainMixerNode.outputVolume = volume
    }

    /// 播放一个音效；`duration` 只对马达这类可变长度的声音有效。
    public func play(_ effect: SoundEffect, duration: Double? = nil) {
        guard !isMuted else { return }
        queue.async { [self] in
            guard !nodes.isEmpty, startIfNeeded(), let buffer = buffer(for: effect, duration: duration) else { return }
            let node = nodes[nextNode]
            nextNode = (nextNode + 1) % nodes.count
            node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !node.isPlaying {
                node.play()
            }
        }
    }

    /// 预先合成常用音效，避免第一次播放时卡顿。
    public func preload(_ effects: [SoundEffect] = [.shutter, .motor, .ding, .beep, .beepFinal]) {
        queue.async { [self] in
            for effect in effects {
                _ = buffer(for: effect, duration: nil)
            }
        }
    }

    /// 停止所有声音（例如取消出片）。
    public func stopAll() {
        queue.async { [self] in
            for node in nodes where node.isPlaying {
                node.stop()
            }
        }
    }

    private func buffer(for effect: SoundEffect, duration: Double?) -> AVAudioPCMBuffer? {
        let key = "\(effect.rawValue)-\(duration.map { String(format: "%.2f", $0) } ?? "default")"
        if let cached = cache[key] { return cached }
        guard let format else { return nil }
        let samples = SoundSynth.render(effect, duration: duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in 0..<samples.count {
            channel[i] = samples[i]
        }
        cache[key] = buffer
        return buffer
    }

    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }
}
