import CoreGraphics
import Foundation

/// 照片堆：新照片永远在最上层，旧照片被挤到旁边。
///
/// 坐标以「y 向下」为准（SwiftUI / UIKit）；Mac 端使用时把 dy 取反。
public enum PileLayout {
    public struct Slot: Equatable, Sendable {
        /// 相对堆锚点（最新一张的中心）的偏移。
        public var offset: CGSize
        /// 倾斜角度（度）。
        public var rotation: Double
        /// 叠放顺序：越新越大。
        public var zIndex: Double
    }

    /// 最多错开几层，再旧的照片停在最后一层下面。
    public static let maxSpread = 6

    /// 第 `index` 张（0 = 最新）的位置。`seed` 用照片自己的 seed，保证每张照片的「随手一放」是固定的。
    public static func slot(index: Int, seed: UInt64, step: CGSize = CGSize(width: -28, height: 18)) -> Slot {
        let i = max(0, min(index, maxSpread))
        var rng = SeededRandom(seed: seed ^ 0x9113)
        let jitterX = CGFloat(rng.signed() * 7)
        let jitterY = CGFloat(rng.signed() * 7)
        let tilt = rng.signed() * 6
        let offset = index == 0
            ? CGSize(width: jitterX * 0.3, height: jitterY * 0.3)
            : CGSize(width: step.width * CGFloat(i) + jitterX, height: step.height * CGFloat(i) + jitterY)
        return Slot(offset: offset, rotation: tilt, zIndex: Double(-index))
    }
}

public extension PhotoRecord {
    /// 第 `frame` 格上的色块（大头贴的色块轮流落在四格上）。
    func blotches(forFrame frame: Int) -> [Blotch] {
        let count = max(1, negatives.count)
        return blotches.enumerated().filter { $0.offset % count == frame }.map(\.element)
    }

    /// 默认题字（参考拍立得玩法里的小彩蛋）。
    static let defaultCaption = String(localized: "我可以见你吗？")
}
