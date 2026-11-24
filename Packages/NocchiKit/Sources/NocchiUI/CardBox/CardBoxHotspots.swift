import CoreGraphics

/// 卡片盒渲染图（`CardBoxBase` / `CardBoxFront`，2000×1500）上的热点。
///
/// 由 `design/blender/cardbox/make_cardbox.py` 渲染时一起算出（`hotspots.json`），坐标归一化到画布、原点左上。
/// 不要手改：重新渲染卡片盒后运行 `python3 design/blender/cardbox/gen_swift_hotspots.py`。
enum CardBoxHotspots {
    struct Tab: Hashable {
        /// 第几张分隔卡：0 = 最前面，26 = 最后面（按首字母归档时就是 A…Z、#）。
        let slot: Int
        /// 分隔卡标签的中心。
        let center: CGPoint
        /// 标签正面露在分隔卡上沿以上的四个角：左上、右上、右下、左下（标签上的字按它斜切上去）。
        let face: [CGPoint]
    }

    /// 画布尺寸（像素）与宽高比。
    static let canvas = CGSize(width: 2000, height: 1500)
    static let canvasAspect: CGFloat = 2000 / 1500

    /// 27 张分隔卡的标签，从前往后（标签留白，字由 App 印上去）。
    static let tabs: [Tab] = [
        Tab(slot: 0, center: CGPoint(x: 0.42418, y: 0.48038), face: [CGPoint(x: 0.40110, y: 0.48119), CGPoint(x: 0.44391, y: 0.44212), CGPoint(x: 0.44713, y: 0.47839), CGPoint(x: 0.40470, y: 0.51796)]),
        Tab(slot: 1, center: CGPoint(x: 0.44347, y: 0.44171), face: [CGPoint(x: 0.42090, y: 0.44183), CGPoint(x: 0.46229, y: 0.40449), CGPoint(x: 0.46593, y: 0.44037), CGPoint(x: 0.42488, y: 0.47821)]),
        Tab(slot: 2, center: CGPoint(x: 0.46658, y: 0.40694), face: [CGPoint(x: 0.44479, y: 0.40657), CGPoint(x: 0.48482, y: 0.37073), CGPoint(x: 0.48828, y: 0.40608), CGPoint(x: 0.44858, y: 0.44241)]),
        Tab(slot: 3, center: CGPoint(x: 0.49433, y: 0.36803), face: [CGPoint(x: 0.47367, y: 0.36725), CGPoint(x: 0.51244, y: 0.33282), CGPoint(x: 0.51497, y: 0.36760), CGPoint(x: 0.47651, y: 0.40251)]),
        Tab(slot: 4, center: CGPoint(x: 0.50843, y: 0.33537), face: [CGPoint(x: 0.48801, y: 0.33404), CGPoint(x: 0.52560, y: 0.30105), CGPoint(x: 0.52881, y: 0.33546), CGPoint(x: 0.49152, y: 0.36892)]),
        Tab(slot: 5, center: CGPoint(x: 0.36464, y: 0.44915), face: [CGPoint(x: 0.34100, y: 0.44943), CGPoint(x: 0.38426, y: 0.41175), CGPoint(x: 0.38811, y: 0.44765), CGPoint(x: 0.34522, y: 0.48584)]),
        Tab(slot: 6, center: CGPoint(x: 0.38576, y: 0.40813), face: [CGPoint(x: 0.36271, y: 0.40775), CGPoint(x: 0.40459, y: 0.37173), CGPoint(x: 0.40865, y: 0.40726), CGPoint(x: 0.36712, y: 0.44377)]),
        Tab(slot: 7, center: CGPoint(x: 0.41423, y: 0.37835), face: [CGPoint(x: 0.39236, y: 0.37768), CGPoint(x: 0.43283, y: 0.34298), CGPoint(x: 0.43601, y: 0.37780), CGPoint(x: 0.39588, y: 0.41299)]),
        Tab(slot: 8, center: CGPoint(x: 0.43534, y: 0.33600), face: [CGPoint(x: 0.41416, y: 0.33478), CGPoint(x: 0.45343, y: 0.30157), CGPoint(x: 0.45645, y: 0.33601), CGPoint(x: 0.41749, y: 0.36968)]),
        Tab(slot: 9, center: CGPoint(x: 0.46107, y: 0.31255), face: [CGPoint(x: 0.44085, y: 0.31110), CGPoint(x: 0.47882, y: 0.27901), CGPoint(x: 0.48127, y: 0.31280), CGPoint(x: 0.44360, y: 0.34534)]),
        Tab(slot: 10, center: CGPoint(x: 0.30699, y: 0.42227), face: [CGPoint(x: 0.28295, y: 0.42216), CGPoint(x: 0.32658, y: 0.38574), CGPoint(x: 0.33081, y: 0.42117), CGPoint(x: 0.28756, y: 0.45807)]),
        Tab(slot: 11, center: CGPoint(x: 0.33494, y: 0.38535), face: [CGPoint(x: 0.31201, y: 0.38482), CGPoint(x: 0.35422, y: 0.34985), CGPoint(x: 0.35772, y: 0.38468), CGPoint(x: 0.31586, y: 0.42012)]),
        Tab(slot: 12, center: CGPoint(x: 0.35998, y: 0.34604), face: [CGPoint(x: 0.33791, y: 0.34502), CGPoint(x: 0.37881, y: 0.31149), CGPoint(x: 0.38193, y: 0.34587), CGPoint(x: 0.34136, y: 0.37986)]),
        Tab(slot: 13, center: CGPoint(x: 0.37757, y: 0.31407), face: [CGPoint(x: 0.35589, y: 0.31253), CGPoint(x: 0.39553, y: 0.28038), CGPoint(x: 0.39914, y: 0.31438), CGPoint(x: 0.35982, y: 0.34699)]),
        Tab(slot: 14, center: CGPoint(x: 0.39992, y: 0.27821), face: [CGPoint(x: 0.37898, y: 0.27625), CGPoint(x: 0.41745, y: 0.24538), CGPoint(x: 0.42078, y: 0.27894), CGPoint(x: 0.38262, y: 0.31026)]),
        Tab(slot: 15, center: CGPoint(x: 0.24481, y: 0.38212), face: [CGPoint(x: 0.22015, y: 0.38138), CGPoint(x: 0.26424, y: 0.34645), CGPoint(x: 0.26919, y: 0.38161), CGPoint(x: 0.22549, y: 0.41703)]),
        Tab(slot: 16, center: CGPoint(x: 0.27645, y: 0.35471), face: [CGPoint(x: 0.25301, y: 0.35373), CGPoint(x: 0.29560, y: 0.32001), CGPoint(x: 0.29969, y: 0.35449), CGPoint(x: 0.25746, y: 0.38867)]),
        Tab(slot: 17, center: CGPoint(x: 0.30143, y: 0.31537), face: [CGPoint(x: 0.27880, y: 0.31389), CGPoint(x: 0.32011, y: 0.28157), CGPoint(x: 0.32389, y: 0.31563), CGPoint(x: 0.28292, y: 0.34841)]),
        Tab(slot: 18, center: CGPoint(x: 0.32151, y: 0.28034), face: [CGPoint(x: 0.29936, y: 0.27836), CGPoint(x: 0.33942, y: 0.24737), CGPoint(x: 0.34351, y: 0.28107), CGPoint(x: 0.30376, y: 0.31252)]),
        Tab(slot: 19, center: CGPoint(x: 0.34397, y: 0.25204), face: [CGPoint(x: 0.32242, y: 0.24971), CGPoint(x: 0.36126, y: 0.21987), CGPoint(x: 0.36538, y: 0.25312), CGPoint(x: 0.32684, y: 0.28341)]),
        Tab(slot: 20, center: CGPoint(x: 0.19748, y: 0.35256), face: [CGPoint(x: 0.17284, y: 0.35154), CGPoint(x: 0.21724, y: 0.31769), CGPoint(x: 0.22185, y: 0.35236), CGPoint(x: 0.17783, y: 0.38668)]),
        Tab(slot: 21, center: CGPoint(x: 0.22304, y: 0.32146), face: [CGPoint(x: 0.19919, y: 0.32002), CGPoint(x: 0.24214, y: 0.28749), CGPoint(x: 0.24666, y: 0.32167), CGPoint(x: 0.20407, y: 0.35466)]),
        Tab(slot: 22, center: CGPoint(x: 0.24801, y: 0.28804), face: [CGPoint(x: 0.22492, y: 0.28618), CGPoint(x: 0.26654, y: 0.25493), CGPoint(x: 0.27090, y: 0.28866), CGPoint(x: 0.22961, y: 0.32037)]),
        Tab(slot: 23, center: CGPoint(x: 0.27664, y: 0.26083), face: [CGPoint(x: 0.25460, y: 0.25874), CGPoint(x: 0.29491, y: 0.22857), CGPoint(x: 0.29853, y: 0.26171), CGPoint(x: 0.25853, y: 0.29232)]),
        Tab(slot: 24, center: CGPoint(x: 0.30037, y: 0.23161), face: [CGPoint(x: 0.27908, y: 0.22921), CGPoint(x: 0.31819, y: 0.20015), CGPoint(x: 0.32153, y: 0.23282), CGPoint(x: 0.28273, y: 0.26230)]),
        Tab(slot: 25, center: CGPoint(x: 0.14282, y: 0.32619), face: [CGPoint(x: 0.11774, y: 0.32477), CGPoint(x: 0.16237, y: 0.29208), CGPoint(x: 0.16759, y: 0.32637), CGPoint(x: 0.12334, y: 0.35953)]),
        Tab(slot: 26, center: CGPoint(x: 0.17387, y: 0.29861), face: [CGPoint(x: 0.14995, y: 0.29696), CGPoint(x: 0.19312, y: 0.26541), CGPoint(x: 0.19754, y: 0.29906), CGPoint(x: 0.15472, y: 0.33106)]),
    ]

    /// 盒口（四边形：前板右端、右板后端、后板左端、前板左端）。
    static let mouth: [CGPoint] = [
        CGPoint(x: 0.55146, y: 0.66755),
        CGPoint(x: 0.73476, y: 0.46858),
        CGPoint(x: 0.30510, y: 0.25054),
        CGPoint(x: 0.10508, y: 0.40303)
    ]

    /// 盒子在画布里的外框（含笔，不含地面阴影）。
    static let boxBounds = CGRect(x: 0.07319, y: 0.23305, width: 0.69362, height: 0.68695)

    /// 分隔卡上沿在画面里的方向（单位向量，画布像素空间）：和右侧板上沿平行（盒口第 0 → 1 个角）。
    static var dividerDirection: CGVector {
        let dx = (mouth[1].x - mouth[0].x) * canvas.width
        let dy = (mouth[1].y - mouth[0].y) * canvas.height
        let length = max(0.001, hypot(dx, dy))
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// 盒子内部沿分隔卡方向的宽度（画布像素）。
    static var dividerLength: CGFloat {
        hypot((mouth[1].x - mouth[0].x) * canvas.width, (mouth[1].y - mouth[0].y) * canvas.height)
    }

    /// 盒口前沿上靠右的一点（前板上沿 60% 处）。
    static var slot: CGPoint {
        let a = mouth[3], b = mouth[0]
        return CGPoint(x: a.x + (b.x - a.x) * 0.6, y: a.y + (b.y - a.y) * 0.6)
    }

    /// 第 slot 张分隔卡的标签（超出范围时取最近的一张）。
    static func tab(slot: Int) -> Tab {
        tabs[min(max(slot, 0), tabs.count - 1)]
    }
}
