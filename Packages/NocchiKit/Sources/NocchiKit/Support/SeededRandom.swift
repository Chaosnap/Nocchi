import Foundation

/// 确定性的 SplitMix64 随机数发生器。
///
/// 颗粒、漏光、色块都用照片自己的 seed 生成，所以预览、显影动画和最终导出
/// 得到的是同一张图。
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1) 均匀分布。
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// [lower, upper) 均匀分布。
    public mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    /// [-1, 1) 均匀分布。
    public mutating func signed() -> Double {
        unit() * 2 - 1
    }

    /// 0..<count 的整数。
    public mutating func index(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(next() % UInt64(count))
    }

    /// 生成一个适合存进 JSON 的 seed（小于 2^52，Double 可精确表示）。
    public static func makeSeed() -> UInt64 {
        UInt64.random(in: 0..<(1 << 52))
    }
}
