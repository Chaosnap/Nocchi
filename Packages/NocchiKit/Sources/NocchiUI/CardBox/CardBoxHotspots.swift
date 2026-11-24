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
        Tab(slot: 0, center: CGPoint(x: 0.41809, y: 0.48920), face: [CGPoint(x: 0.40124, y: 0.48441), CGPoint(x: 0.43178, y: 0.45654), CGPoint(x: 0.43508, y: 0.49269), CGPoint(x: 0.40481, y: 0.52091)]),
        Tab(slot: 1, center: CGPoint(x: 0.44037, y: 0.44790), face: [CGPoint(x: 0.42388, y: 0.44264), CGPoint(x: 0.45332, y: 0.41609), CGPoint(x: 0.45700, y: 0.45181), CGPoint(x: 0.42781, y: 0.47872)]),
        Tab(slot: 2, center: CGPoint(x: 0.46624, y: 0.41071), face: [CGPoint(x: 0.45039, y: 0.40516), CGPoint(x: 0.47877, y: 0.37976), CGPoint(x: 0.48224, y: 0.41492), CGPoint(x: 0.45409, y: 0.44067)]),
        Tab(slot: 3, center: CGPoint(x: 0.49652, y: 0.36963), face: [CGPoint(x: 0.48166, y: 0.36387), CGPoint(x: 0.50907, y: 0.33953), CGPoint(x: 0.51160, y: 0.37409), CGPoint(x: 0.48441, y: 0.39877)]),
        Tab(slot: 4, center: CGPoint(x: 0.51307, y: 0.33497), face: [CGPoint(x: 0.49832, y: 0.32885), CGPoint(x: 0.52482, y: 0.30560), CGPoint(x: 0.52801, y: 0.33975), CGPoint(x: 0.50172, y: 0.36334)]),
        Tab(slot: 5, center: CGPoint(x: 0.35892, y: 0.45800), face: [CGPoint(x: 0.34158, y: 0.45289), CGPoint(x: 0.37244, y: 0.42601), CGPoint(x: 0.37636, y: 0.46179), CGPoint(x: 0.34577, y: 0.48902)]),
        Tab(slot: 6, center: CGPoint(x: 0.38305, y: 0.41446), face: [CGPoint(x: 0.36616, y: 0.40891), CGPoint(x: 0.39594, y: 0.38330), CGPoint(x: 0.40004, y: 0.41867), CGPoint(x: 0.37051, y: 0.44463)]),
        Tab(slot: 7, center: CGPoint(x: 0.41428, y: 0.38233), face: [CGPoint(x: 0.39840, y: 0.37666), CGPoint(x: 0.42709, y: 0.35205), CGPoint(x: 0.43030, y: 0.38669), CGPoint(x: 0.40185, y: 0.41163)]),
        Tab(slot: 8, center: CGPoint(x: 0.43799, y: 0.33792), face: [CGPoint(x: 0.42268, y: 0.33190), CGPoint(x: 0.45045, y: 0.30842), CGPoint(x: 0.45347, y: 0.34264), CGPoint(x: 0.42592, y: 0.36645)]),
        Tab(slot: 9, center: CGPoint(x: 0.46612, y: 0.31244), face: [CGPoint(x: 0.45162, y: 0.30634), CGPoint(x: 0.47839, y: 0.28372), CGPoint(x: 0.48082, y: 0.31726), CGPoint(x: 0.45426, y: 0.34020)]),
        Tab(slot: 10, center: CGPoint(x: 0.30164, y: 0.43114), face: [CGPoint(x: 0.28396, y: 0.42581), CGPoint(x: 0.31507, y: 0.39984), CGPoint(x: 0.31937, y: 0.43514), CGPoint(x: 0.28853, y: 0.46146)]),
        Tab(slot: 11, center: CGPoint(x: 0.33258, y: 0.39177), face: [CGPoint(x: 0.31586, y: 0.38622), CGPoint(x: 0.34587, y: 0.36136), CGPoint(x: 0.34941, y: 0.39603), CGPoint(x: 0.31965, y: 0.42123)]),
        Tab(slot: 12, center: CGPoint(x: 0.36042, y: 0.35026), face: [CGPoint(x: 0.34441, y: 0.34441), CGPoint(x: 0.37341, y: 0.32063), CGPoint(x: 0.37656, y: 0.35482), CGPoint(x: 0.34779, y: 0.37892)]),
        Tab(slot: 13, center: CGPoint(x: 0.38068, y: 0.31623), face: [CGPoint(x: 0.36492, y: 0.31005), CGPoint(x: 0.39295, y: 0.28732), CGPoint(x: 0.39655, y: 0.32110), CGPoint(x: 0.36875, y: 0.34416)]),
        Tab(slot: 14, center: CGPoint(x: 0.40549, y: 0.27853), face: [CGPoint(x: 0.39034, y: 0.27210), CGPoint(x: 0.41747, y: 0.25033), CGPoint(x: 0.42078, y: 0.28365), CGPoint(x: 0.39386, y: 0.30574)]),
        Tab(slot: 15, center: CGPoint(x: 0.23986, y: 0.39107), face: [CGPoint(x: 0.22162, y: 0.38534), CGPoint(x: 0.25306, y: 0.36042), CGPoint(x: 0.25808, y: 0.39546), CGPoint(x: 0.22691, y: 0.42072)]),
        Tab(slot: 16, center: CGPoint(x: 0.27449, y: 0.36128), face: [CGPoint(x: 0.25731, y: 0.35545), CGPoint(x: 0.28759, y: 0.33148), CGPoint(x: 0.29173, y: 0.36580), CGPoint(x: 0.26170, y: 0.39010)]),
        Tab(slot: 17, center: CGPoint(x: 0.30230, y: 0.31981), face: [CGPoint(x: 0.28579, y: 0.31368), CGPoint(x: 0.31508, y: 0.29076), CGPoint(x: 0.31888, y: 0.32464), CGPoint(x: 0.28984, y: 0.34788)]),
        Tab(slot: 18, center: CGPoint(x: 0.32506, y: 0.28282), face: [CGPoint(x: 0.30889, y: 0.27638), CGPoint(x: 0.33722, y: 0.25447), CGPoint(x: 0.34130, y: 0.28795), CGPoint(x: 0.31319, y: 0.31019)]),
        Tab(slot: 19, center: CGPoint(x: 0.35000, y: 0.25269), face: [CGPoint(x: 0.33430, y: 0.24605), CGPoint(x: 0.36170, y: 0.22501), CGPoint(x: 0.36578, y: 0.25801), CGPoint(x: 0.33860, y: 0.27938)]),
        Tab(slot: 20, center: CGPoint(x: 0.19283, y: 0.36157), face: [CGPoint(x: 0.17466, y: 0.35571), CGPoint(x: 0.20631, y: 0.33157), CGPoint(x: 0.21100, y: 0.36612), CGPoint(x: 0.17961, y: 0.39060)]),
        Tab(slot: 21, center: CGPoint(x: 0.22145, y: 0.32818), face: [CGPoint(x: 0.20391, y: 0.32207), CGPoint(x: 0.23445, y: 0.29894), CGPoint(x: 0.23901, y: 0.33297), CGPoint(x: 0.20873, y: 0.35643)]),
        Tab(slot: 22, center: CGPoint(x: 0.24927, y: 0.29268), face: [CGPoint(x: 0.23235, y: 0.28633), CGPoint(x: 0.26186, y: 0.26417), CGPoint(x: 0.26623, y: 0.29772), CGPoint(x: 0.23696, y: 0.32020)]),
        Tab(slot: 23, center: CGPoint(x: 0.28053, y: 0.26352), face: [CGPoint(x: 0.26451, y: 0.25708), CGPoint(x: 0.29302, y: 0.23575), CGPoint(x: 0.29663, y: 0.26868), CGPoint(x: 0.26835, y: 0.29032)]),
        Tab(slot: 24, center: CGPoint(x: 0.30675, y: 0.23253), face: [CGPoint(x: 0.29135, y: 0.22593), CGPoint(x: 0.31893, y: 0.20543), CGPoint(x: 0.32226, y: 0.23786), CGPoint(x: 0.29489, y: 0.25866)]),
        Tab(slot: 25, center: CGPoint(x: 0.13854, y: 0.33523), face: [CGPoint(x: 0.11996, y: 0.32914), CGPoint(x: 0.15178, y: 0.30583), CGPoint(x: 0.15707, y: 0.34000), CGPoint(x: 0.12552, y: 0.36365)]),
        Tab(slot: 26, center: CGPoint(x: 0.17262, y: 0.30543), face: [CGPoint(x: 0.15505, y: 0.29926), CGPoint(x: 0.18574, y: 0.27683), CGPoint(x: 0.19020, y: 0.31032), CGPoint(x: 0.15976, y: 0.33307)]),
    ]

    /// 盒口（四边形：前板右端、右板后端、后板左端、前板左端）。
    static let mouth: [CGPoint] = [
        CGPoint(x: 0.55049, y: 0.66940),
        CGPoint(x: 0.73245, y: 0.47189),
        CGPoint(x: 0.30594, y: 0.25546),
        CGPoint(x: 0.10739, y: 0.40682)
    ]

    /// 盒子在画布里的外框（含笔，不含地面阴影）。
    static let boxBounds = CGRect(x: 0.07573, y: 0.23809, width: 0.68853, height: 0.68191)

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
