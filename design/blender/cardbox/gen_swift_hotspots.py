"""Regenerate Packages/NocchiKit/Sources/NocchiUI/CardBox/CardBoxHotspots.swift from hotspots.json.

Run after every card box re-render:  python3 design/blender/cardbox/gen_swift_hotspots.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
d = json.load(open(os.path.join(HERE, "hotspots.json")))
tabs = "\n".join(
    f'        Tab(letter: "{t["letter"]}", center: CGPoint(x: {t["center"][0]:.5f}, y: {t["center"][1]:.5f})),'
    for t in d["tabs"]
)
mouth = ",\n        ".join(f"CGPoint(x: {x:.5f}, y: {y:.5f})" for x, y in d["mouth"])
b = d["boxBounds"]
w, h = d["canvas"]
src = f'''import CoreGraphics

/// 卡片盒渲染图（`CardBoxBase` / `CardBoxFront`，{w}×{h}）上的热点。
///
/// 由 `design/blender/cardbox/make_cardbox.py` 渲染时一起算出（`hotspots.json`），坐标归一化到画布、原点左上。
/// 不要手改：重新渲染卡片盒后运行 `python3 design/blender/cardbox/gen_swift_hotspots.py`。
enum CardBoxHotspots {{
    struct Tab: Hashable {{
        let letter: String
        /// 分隔卡标签的中心。
        let center: CGPoint
    }}

    /// 画布尺寸（像素）与宽高比。
    static let canvas = CGSize(width: {w}, height: {h})
    static let canvasAspect: CGFloat = {w} / {h}

    /// 27 张分隔卡的标签（A–Z 与 #），从前往后。
    static let tabs: [Tab] = [
{tabs}
    ]

    /// 盒口（四边形：前板右端、右板后端、后板左端、前板左端）。
    static let mouth: [CGPoint] = [
        {mouth}
    ]

    /// 盒子在画布里的外框（含笔，不含地面阴影）。
    static let boxBounds = CGRect(x: {b[0]:.5f}, y: {b[1]:.5f}, width: {b[2]:.5f}, height: {b[3]:.5f})

    /// 分隔卡上沿在画面里的方向（单位向量，画布像素空间）：和右侧板上沿平行（盒口第 0 → 1 个角）。
    static var dividerDirection: CGVector {{
        let dx = (mouth[1].x - mouth[0].x) * canvas.width
        let dy = (mouth[1].y - mouth[0].y) * canvas.height
        let length = max(0.001, hypot(dx, dy))
        return CGVector(dx: dx / length, dy: dy / length)
    }}

    /// 盒子内部沿分隔卡方向的宽度（画布像素）。
    static var dividerLength: CGFloat {{
        hypot((mouth[1].x - mouth[0].x) * canvas.width, (mouth[1].y - mouth[0].y) * canvas.height)
    }}

    /// 盒口前沿上靠右的一点（前板上沿 60% 处）。
    static var slot: CGPoint {{
        let a = mouth[3], b = mouth[0]
        return CGPoint(x: a.x + (b.x - a.x) * 0.6, y: a.y + (b.y - a.y) * 0.6)
    }}

    static func tab(for letter: String) -> Tab? {{
        tabs.first {{ $0.letter == letter }}
    }}
}}
'''
out = os.path.join(REPO, "Packages", "NocchiKit", "Sources", "NocchiUI", "CardBox", "CardBoxHotspots.swift")
open(out, "w").write(src)
print("wrote", os.path.relpath(out, REPO), len(d["tabs"]), "tabs, canvas", w, h)
