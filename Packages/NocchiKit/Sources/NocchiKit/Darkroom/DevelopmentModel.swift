import Foundation

/// 显影进度模型：时间推进 + 甩动加速。
///
/// 进度 0 时相纸是一片乳灰色，1 时与导出的成片完全一致。
public struct DevelopmentModel: Codable, Equatable, Sendable {
    /// 不甩的情况下完全显影需要的秒数。
    public var baseDuration: TimeInterval
    /// 开始显影前的延迟（大头贴机一格一格显影）。
    public var startDelay: TimeInterval
    /// 甩动带来的额外速度倍率上限。
    public var maxBoost: Double
    /// 甩动加速每秒衰减量。
    public var boostDecayPerSecond: Double

    public private(set) var elapsed: TimeInterval = 0
    public private(set) var progress: Double = 0
    public private(set) var boost: Double = 0

    public init(baseDuration: TimeInterval = 15, startDelay: TimeInterval = 0, maxBoost: Double = 3, boostDecayPerSecond: Double = 1.4) {
        self.baseDuration = max(0.1, baseDuration)
        self.startDelay = max(0, startDelay)
        self.maxBoost = maxBoost
        self.boostDecayPerSecond = boostDecayPerSecond
    }

    public var isComplete: Bool { progress >= 1 }
    public var hasStarted: Bool { elapsed >= startDelay }

    /// 当前速度倍率（1 = 正常）。
    public var rate: Double { 1 + boost }

    /// 预计剩余秒数（按当前倍率）。
    public var remaining: TimeInterval {
        let waiting = max(0, startDelay - elapsed)
        return waiting + (1 - progress) * baseDuration / rate
    }

    /// 推进 dt 秒。
    public mutating func advance(by dt: TimeInterval) {
        guard dt > 0, !isComplete else { return }
        let before = elapsed
        elapsed += dt
        let active = max(0, elapsed - max(before, startDelay))
        guard active > 0 else { return }
        progress = min(1, progress + active * rate / baseDuration)
        boost = max(0, boost - boostDecayPerSecond * active)
    }

    /// 一次甩动（energy 0…1）。
    public mutating func addShake(energy: Double) {
        guard !isComplete else { return }
        boost = min(maxBoost, boost + 0.6 * min(max(energy, 0), 1) + 0.15)
    }

    /// 直接完成（例如恢复已显影的照片）。
    public mutating func complete() {
        progress = 1
        boost = 0
        elapsed = max(elapsed, startDelay)
    }
}

/// 某个显影进度下，界面该怎样画这张照片。t = 1 时严格等于成片。
public struct DevelopmentVisual: Equatable, Sendable {
    public var imageOpacity: Double
    public var saturation: Double
    public var contrast: Double
    public var brightness: Double
    /// 模糊半径，相对于图像窗口宽度。
    public var blurFraction: Double
    /// 乳青色雾面的不透明度。
    public var hazeOpacity: Double
    /// 各通道乘数：蓝色先出来，红色最后出来。
    public var red: Double
    public var green: Double
    public var blue: Double

    public static let developed = DevelopmentVisual(
        imageOpacity: 1, saturation: 1, contrast: 1, brightness: 0,
        blurFraction: 0, hazeOpacity: 0, red: 1, green: 1, blue: 1
    )

    public static func at(_ progress: Double) -> DevelopmentVisual {
        let t = min(max(progress, 0), 1)
        if t >= 1 { return .developed }
        let s: (Double, Double, Double) -> Double = ColorMath.smoothstep
        return DevelopmentVisual(
            imageOpacity: s(0.03, 0.55, t),
            saturation: s(0.25, 0.95, t),
            contrast: 0.55 + 0.45 * s(0.1, 0.9, t),
            brightness: 0.12 * (1 - s(0.2, 1.0, t)),
            blurFraction: 0.02 * (1 - s(0.0, 0.45, t)),
            hazeOpacity: 0.45 * (1 - s(0.0, 0.8, t)),
            red: 0.80 + 0.20 * s(0.35, 1.0, t),
            green: 0.88 + 0.12 * s(0.2, 0.9, t),
            blue: 1
        )
    }
}
