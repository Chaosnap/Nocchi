import CoreGraphics

/// 卡片盒渲染图（`CardBoxBase` / `CardBoxFront`，2000×1500）上的热点。
///
/// 由 `design/blender/cardbox/make_cardbox.py` 渲染时一起算出（`hotspots.json`），坐标归一化到画布、原点左上。
/// 不要手改：重新渲染卡片盒后运行 `python3 design/blender/cardbox/gen_swift_hotspots.py`。
enum CardBoxHotspots {
    struct Tab: Hashable {
        let letter: String
        /// 分隔卡标签的中心。
        let center: CGPoint
    }

    /// 画布尺寸（像素）与宽高比。
    static let canvas = CGSize(width: 2000, height: 1500)
    static let canvasAspect: CGFloat = 2000 / 1500

    /// 27 张分隔卡的标签（A–Z 与 #），从前往后。
    static let tabs: [Tab] = [
        Tab(letter: "A", center: CGPoint(x: 0.42037, y: 0.48390)),
        Tab(letter: "B", center: CGPoint(x: 0.44163, y: 0.44339)),
        Tab(letter: "C", center: CGPoint(x: 0.46658, y: 0.40694)),
        Tab(letter: "D", center: CGPoint(x: 0.49605, y: 0.36649)),
        Tab(letter: "E", center: CGPoint(x: 0.51176, y: 0.33241)),
        Tab(letter: "F", center: CGPoint(x: 0.36079, y: 0.45254)),
        Tab(letter: "G", center: CGPoint(x: 0.38390, y: 0.40975)),
        Tab(letter: "H", center: CGPoint(x: 0.41423, y: 0.37835)),
        Tab(letter: "I", center: CGPoint(x: 0.43708, y: 0.33451)),
        Tab(letter: "J", center: CGPoint(x: 0.46444, y: 0.30967)),
        Tab(letter: "K", center: CGPoint(x: 0.30310, y: 0.42555)),
        Tab(letter: "L", center: CGPoint(x: 0.33306, y: 0.38692)),
        Tab(letter: "M", center: CGPoint(x: 0.35998, y: 0.34604)),
        Tab(letter: "N", center: CGPoint(x: 0.37933, y: 0.31263)),
        Tab(letter: "O", center: CGPoint(x: 0.40334, y: 0.27544)),
        Tab(letter: "P", center: CGPoint(x: 0.24088, y: 0.38527)),
        Tab(letter: "Q", center: CGPoint(x: 0.27455, y: 0.35623)),
        Tab(letter: "R", center: CGPoint(x: 0.30143, y: 0.31537)),
        Tab(letter: "S", center: CGPoint(x: 0.32329, y: 0.27895)),
        Tab(letter: "T", center: CGPoint(x: 0.34742, y: 0.24936)),
        Tab(letter: "U", center: CGPoint(x: 0.19353, y: 0.35561)),
        Tab(letter: "V", center: CGPoint(x: 0.22113, y: 0.32292)),
        Tab(letter: "W", center: CGPoint(x: 0.24801, y: 0.28804)),
        Tab(letter: "X", center: CGPoint(x: 0.27843, y: 0.25947)),
        Tab(letter: "Y", center: CGPoint(x: 0.30384, y: 0.22900)),
        Tab(letter: "Z", center: CGPoint(x: 0.13885, y: 0.32914)),
        Tab(letter: "#", center: CGPoint(x: 0.17195, y: 0.30003)),
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

    static func tab(for letter: String) -> Tab? {
        tabs.first { $0.letter == letter }
    }
}
