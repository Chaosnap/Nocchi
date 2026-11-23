import Foundation

/// 甩得太猛时出现在相片上的药水色块（彩蛋）。
///
/// 坐标归一化到图像窗口：x、y ∈ 0…1，原点在左上；半径相对于窗口宽度。
public struct Blotch: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// 药水没铺开：发白、发青的亮斑。
        case pale
        /// 药水堆积：偏品红 / 棕的暗斑。
        case stain
    }

    public var x: Double
    public var y: Double
    public var radius: Double
    public var color: String
    public var strength: Double
    public var kind: Kind

    public init(x: Double, y: Double, radius: Double, color: String, strength: Double, kind: Kind) {
        self.x = x
        self.y = y
        self.radius = radius
        self.color = color
        self.strength = strength
        self.kind = kind
    }

    private static let paleColors = ["#DDEBE6", "#E8E2C8", "#D2E4F0"]
    private static let stainColors = ["#8A3A6A", "#7A4A2A", "#5A3A7A"]

    /// 由照片 seed 和序号确定性地生成一个色块；靠近边缘的概率更高（像药水从边上挤进来）。
    public static func make(seed: UInt64, index: Int) -> Blotch {
        var rng = SeededRandom(seed: seed &+ UInt64(index + 1) &* 0x2545_F491_4F6C_DD1D)
        let kind: Kind = rng.unit() < 0.6 ? .pale : .stain
        let edgeBias = rng.unit()
        var x = rng.unit()
        var y = rng.unit()
        if edgeBias < 0.65 {
            switch rng.index(4) {
            case 0: x = rng.range(0, 0.18)
            case 1: x = rng.range(0.82, 1)
            case 2: y = rng.range(0, 0.18)
            default: y = rng.range(0.82, 1)
            }
        }
        let palette = kind == .pale ? paleColors : stainColors
        return Blotch(
            x: x,
            y: y,
            radius: rng.range(0.08, 0.22),
            color: palette[rng.index(palette.count)],
            strength: rng.range(0.45, 0.85),
            kind: kind
        )
    }

    /// 一张照片最多出现的色块数量。
    public static let maximumPerPhoto = 5
}
