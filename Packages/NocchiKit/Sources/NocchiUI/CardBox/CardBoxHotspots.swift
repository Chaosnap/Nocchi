import CoreGraphics

/// 卡片盒渲染图（`CardBoxBase` / `CardBoxFront`，1600×1200）上的热点。
///
/// 由 `design/blender/cardbox/make_cardbox.py` 渲染时一起算出（`hotspots.json`），坐标归一化到画布、原点左上。
/// 重新渲染卡片盒后要同步更新这里。
enum CardBoxHotspots {
    struct Tab: Hashable {
        let letter: String
        /// 分隔卡标签的中心。
        let center: CGPoint
    }

    /// 画布宽高比（4:3）。
    static let canvasAspect: CGFloat = 1600 / 1200

    /// 27 张分隔卡的标签（A–Z 与 #）。
    static let tabs: [Tab] = [
        Tab(letter: "A", center: CGPoint(x: 0.46044, y: 0.40910)),
        Tab(letter: "B", center: CGPoint(x: 0.48584, y: 0.36072)),
        Tab(letter: "C", center: CGPoint(x: 0.51563, y: 0.31718)),
        Tab(letter: "D", center: CGPoint(x: 0.55084, y: 0.26886)),
        Tab(letter: "E", center: CGPoint(x: 0.56961, y: 0.22816)),
        Tab(letter: "F", center: CGPoint(x: 0.38928, y: 0.37165)),
        Tab(letter: "G", center: CGPoint(x: 0.41688, y: 0.32053)),
        Tab(letter: "H", center: CGPoint(x: 0.45311, y: 0.28303)),
        Tab(letter: "I", center: CGPoint(x: 0.48040, y: 0.23067)),
        Tab(letter: "J", center: CGPoint(x: 0.51308, y: 0.20099)),
        Tab(letter: "K", center: CGPoint(x: 0.32037, y: 0.33940)),
        Tab(letter: "L", center: CGPoint(x: 0.35616, y: 0.29326)),
        Tab(letter: "M", center: CGPoint(x: 0.38830, y: 0.24444)),
        Tab(letter: "N", center: CGPoint(x: 0.41143, y: 0.20453)),
        Tab(letter: "O", center: CGPoint(x: 0.44010, y: 0.16011)),
        Tab(letter: "P", center: CGPoint(x: 0.24606, y: 0.29129)),
        Tab(letter: "Q", center: CGPoint(x: 0.28627, y: 0.25661)),
        Tab(letter: "R", center: CGPoint(x: 0.31837, y: 0.20780)),
        Tab(letter: "S", center: CGPoint(x: 0.34448, y: 0.16430)),
        Tab(letter: "T", center: CGPoint(x: 0.37330, y: 0.12896)),
        Tab(letter: "U", center: CGPoint(x: 0.18949, y: 0.25586)),
        Tab(letter: "V", center: CGPoint(x: 0.22246, y: 0.21682)),
        Tab(letter: "W", center: CGPoint(x: 0.25457, y: 0.17516)),
        Tab(letter: "X", center: CGPoint(x: 0.29090, y: 0.14104)),
        Tab(letter: "Y", center: CGPoint(x: 0.32125, y: 0.10464)),
        Tab(letter: "Z", center: CGPoint(x: 0.12418, y: 0.22425)),
        Tab(letter: "#", center: CGPoint(x: 0.16371, y: 0.18948)),
    ]

    /// 盒口（四边形：前板右端、右板后端、后板左端、前板左端）。
    static let mouth: [CGPoint] = [
        CGPoint(x: 0.61702, y: 0.62846),
        CGPoint(x: 0.83597, y: 0.39080),
        CGPoint(x: 0.32275, y: 0.13037),
        CGPoint(x: 0.08385, y: 0.31250)
    ]

    /// 盒子在画布里的外框（含笔，不含地面阴影）。
    static let boxBounds = CGRect(x: 0.04575, y: 0.10947, width: 0.78274, height: 0.71106)

    /// 抽卡时卡片冒出来的位置：前板上沿 60% 处（最前面的一格，下半截被 `CardBoxFront` 挡住）。
    static var slot: CGPoint {
        let a = mouth[3], b = mouth[0]
        return CGPoint(x: a.x + (b.x - a.x) * 0.6, y: a.y + (b.y - a.y) * 0.6)
    }

    static func tab(for letter: String) -> Tab? {
        tabs.first { $0.letter == letter }
    }
}
