import CoreGraphics
import Foundation

/// 甩一甩检测：统计快速的方向反转。
///
/// Mac 上喂鼠标拖动位置（点），iPhone 上喂加速度（g）。
public struct ShakeDetector: Sendable {
    public struct Config: Sendable, Equatable {
        /// 低于这个速度（或加速度）的移动不算甩。
        public var minMagnitude: Double
        /// 达到这个速度算「很猛」。
        public var violentMagnitude: Double
        /// 一秒内反转次数达到这个值、且速度很猛时，触发色块彩蛋。
        public var violentReversalsPerSecond: Double
        /// 判定为反转的最小夹角余弦（-0.3 ≈ 107°）。
        public var reversalCosine: Double

        public init(minMagnitude: Double, violentMagnitude: Double, violentReversalsPerSecond: Double, reversalCosine: Double = -0.3) {
            self.minMagnitude = minMagnitude
            self.violentMagnitude = violentMagnitude
            self.violentReversalsPerSecond = violentReversalsPerSecond
            self.reversalCosine = reversalCosine
        }

        /// 鼠标拖动（点 / 秒）。
        public static let mouse = Config(minMagnitude: 450, violentMagnitude: 3200, violentReversalsPerSecond: 6)
        /// 手机加速度（g）。
        public static let accelerometer = Config(minMagnitude: 1.1, violentMagnitude: 2.8, violentReversalsPerSecond: 7)
    }

    public struct Event: Equatable, Sendable {
        /// 0…1，越猛越大。
        public var energy: Double
        public var isViolent: Bool
        public var reversalsPerSecond: Double
    }

    public let config: Config
    private var lastPosition: CGPoint?
    private var lastTime: TimeInterval?
    private var lastDirection: SIMD2<Double>?
    private var reversals: [TimeInterval] = []

    public init(config: Config = .mouse) {
        self.config = config
    }

    public mutating func reset() {
        lastPosition = nil
        lastTime = nil
        lastDirection = nil
        reversals.removeAll()
    }

    /// 喂入一个位置样本（例如鼠标在屏幕上的位置）。
    public mutating func add(position: CGPoint, at time: TimeInterval) -> Event? {
        defer {
            lastPosition = position
            lastTime = time
        }
        guard let p0 = lastPosition, let t0 = lastTime else { return nil }
        let dt = time - t0
        guard dt > 0.0005 else { return nil }
        let velocity = SIMD2<Double>(Double(position.x - p0.x) / dt, Double(position.y - p0.y) / dt)
        return add(vector: velocity, at: time)
    }

    /// 喂入一个向量样本（速度或加速度）。
    public mutating func add(vector: SIMD2<Double>, at time: TimeInterval) -> Event? {
        let magnitude = (vector * vector).sum().squareRoot()
        guard magnitude >= config.minMagnitude else { return nil }
        let direction = vector / magnitude
        defer { lastDirection = direction }
        guard let previous = lastDirection else { return nil }
        let cosine = (previous * direction).sum()
        guard cosine <= config.reversalCosine else { return nil }

        reversals.append(time)
        reversals.removeAll { time - $0 > 1.0 }
        let rate = Double(reversals.count)
        let energy = min(1, magnitude / config.violentMagnitude)
        let violent = magnitude >= config.violentMagnitude && rate >= config.violentReversalsPerSecond
        return Event(energy: energy, isViolent: violent, reversalsPerSecond: rate)
    }
}
