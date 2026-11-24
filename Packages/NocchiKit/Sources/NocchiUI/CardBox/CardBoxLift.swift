import NocchiKit
import SwiftUI

// MARK: - 「准备抽出来」：悬停时分隔卡从格子里升起一截

/// 悬停在分隔卡标签上时，那张分隔卡从自己那一格里升起一截——「准备抽出来」
/// （参考 shashage.de「What We Borrow」的档案盒：标签往上抬、露出原来藏在格子里的那截纸面，前面的卡照样挡在前面）。
///
/// - 分隔卡沿盒子的竖直方向（标签面的竖边）往上抬约 1.25 个标签高，0.2 秒，先快后慢；移开时 0.18 秒落回去；
/// - 露出来的那截纸面按分隔卡上沿画成平行四边形，颜色取自渲染图里这张标签的纸色（`DividerPaper`），
///   上沿一道纸边的亮线；格口线以下照样被前面的卡片挡住（`SlotMask`）；
/// - 标签本身从 `CardBoxBase` 里按标签面裁出来，跟着一起升；印在标签上的字也跟着走；
/// - 前面几张分隔卡的标签（`FrontTabs`）重新画在上面，所以它是从这几张后面升起来的。
///
/// 抬起的纸面正好盖住原来的标签（纸面的上沿就是标签的下沿），任何时刻都不会出现两张标签。
struct DividerLift: View {
    let slot: Int
    /// 0 = 在格子里，1 = 抬到最高。
    let amount: CGFloat
    let stage: CardBoxStage
    /// 这张分隔卡的标签（印字、悬停提亮、当前那一格的描边）；没有照片的格子在按日期归档时可能没有标签。
    let tab: CardTab?
    let mode: CardIndexMode
    let hoveredKey: String?
    let activeKey: String?

    var body: some View {
        let face = TabFace(slot: slot, stage: stage)
        let geometry = SlotGeometry(slot: slot, stage: stage)
        let rise = face.rise(amount)
        let paper = DividerPaper.color(slot: slot)
        let ends = dividerEnds(geometry)
        let down = face.down(depth: face.height * 6)
        ZStack(alignment: .topLeading) {
            // 露出来的那截纸面（格口线以下被前面的卡片挡住）。
            ZStack(alignment: .topLeading) {
                DividerFaceShape(a: ends.a, b: ends.b, down: down)
                    .fill(LinearGradient(
                        colors: [paper.lit, paper.shade],
                        startPoint: unit(ends.a),
                        endPoint: unit(CGPoint(x: ends.a.x + down.dx * 0.5, y: ends.a.y + down.dy * 0.5))
                    ))
                DividerFaceShape(a: ends.a, b: ends.b, down: down)
                    .stroke(Color(cardHex: 0x6E6452).opacity(0.35), lineWidth: 0.6)
                Path { path in
                    path.move(to: ends.a)
                    path.addLine(to: ends.b)
                }
                .stroke(Color.white.opacity(0.42), lineWidth: 0.9)
            }
            .frame(width: stage.size.width, height: stage.size.height)
            .offset(x: rise.width, y: rise.height)
            .mask { SlotMask(slot: geometry, masked: true) }

            // 标签：从渲染图里裁出来，跟着升。
            BoxArt(name: "CardBoxBase", stage: stage, fallback: false)
                .mask { TabFaceShape(points: face.corners) }
                .offset(x: rise.width, y: rise.height)

            // 标签上印的字（只裁到自己的标签面：前面的标签由 `FrontTabs` 盖在上面）。
            if let tab {
                TabLabels(tabs: [tab], mode: mode, stage: stage, hoveredKey: hoveredKey, activeKey: activeKey, occludedByFront: false)
                    .offset(x: rise.width, y: rise.height)
            }
        }
        .frame(width: stage.size.width, height: stage.size.height)
        .allowsHitTesting(false)
    }

    /// 分隔卡上沿的两头：格口线上、以这一格中点为中心、分隔卡的宽度（两头各收一点，别顶到盒壁外面）。
    private func dividerEnds(_ geometry: SlotGeometry) -> (a: CGPoint, b: CGPoint) {
        let half = CardBoxHotspots.dividerLength * stage.pixelScale * 0.49
        let d = geometry.direction
        return (
            CGPoint(x: geometry.center.x - d.dx * half, y: geometry.center.y - d.dy * half),
            CGPoint(x: geometry.center.x + d.dx * half, y: geometry.center.y + d.dy * half)
        )
    }

    private func unit(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: point.x / max(stage.size.width, 1), y: point.y / max(stage.size.height, 1))
    }
}

/// 分隔卡露出来的纸面：上沿 a → b，往下（沿分隔卡）伸 `down`。
struct DividerFaceShape: Shape {
    let a: CGPoint
    let b: CGPoint
    let down: CGVector

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: CGPoint(x: b.x + down.dx, y: b.y + down.dy))
        path.addLine(to: CGPoint(x: a.x + down.dx, y: a.y + down.dy))
        path.closeSubpath()
        return path
    }
}

/// 抬起的分隔卡前面那几张的标签：从渲染图里按标签面裁出来，原地画在抬起的分隔卡上面。
struct FrontTabs: View {
    /// 在抬起那张前面的分隔卡（编号比它小）。
    let slots: [Int]
    let stage: CardBoxStage

    var body: some View {
        BoxArt(name: "CardBoxBase", stage: stage, fallback: false)
            .mask {
                Path { path in
                    for slot in slots {
                        path.addLines(TabFace(slot: slot, stage: stage).corners)
                        path.closeSubpath()
                    }
                }
            }
            .frame(width: stage.size.width, height: stage.size.height)
            .allowsHitTesting(false)
    }
}

/// 分隔卡的纸色：从 `CardBoxBase` 渲染图里每张标签的中间取的（盒子里的光线下），
/// 露出来的纸面上亮、往下（往盒子里）暗一些。
/// 重新渲染卡片盒后用 `design/blender/cardbox/sample_tab_paper.py` 重新取色。
enum DividerPaper {
    private static let samples: [(UInt8, UInt8, UInt8)] = [
        (176, 173, 164), (179, 176, 169), (178, 173, 166), (177, 171, 164), (177, 168, 161),
        (185, 177, 171), (187, 178, 172), (184, 176, 169), (185, 177, 169), (181, 171, 164),
        (190, 181, 175), (191, 184, 177), (188, 182, 176), (184, 181, 175), (180, 176, 170),
        (188, 185, 179), (189, 185, 178), (190, 185, 179), (186, 182, 177), (181, 178, 173),
        (189, 187, 183), (190, 187, 182), (190, 185, 179), (189, 183, 176), (185, 178, 172),
        (193, 187, 181), (190, 187, 180),
    ]

    static func color(slot: Int) -> (lit: Color, shade: Color) {
        let s = samples[min(max(slot, 0), samples.count - 1)]
        let r = Double(s.0) / 255
        let g = Double(s.1) / 255
        let b = Double(s.2) / 255
        return (
            Color(red: min(1, r * 1.02), green: min(1, g * 1.02), blue: min(1, b * 1.02)),
            Color(red: r * 0.74, green: g * 0.73, blue: b * 0.72)
        )
    }
}

extension TabFace {
    /// 分隔卡往上抬的方向：标签面的竖边（下 → 上），单位向量。
    var up: CGVector {
        let dx = topLeft.x - bottomLeft.x
        let dy = topLeft.y - bottomLeft.y
        let length = max(hypot(dx, dy), 0.001)
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// 抬起 `amount`（0…1）时的位移：抬满约 1.25 个标签高。
    func rise(_ amount: CGFloat) -> CGSize {
        let distance = height * 1.25 * min(max(amount, 0), 1)
        return CGSize(width: up.dx * distance, height: up.dy * distance)
    }

    /// 沿分隔卡往下 `depth`。
    func down(depth: CGFloat) -> CGVector {
        CGVector(dx: -up.dx * depth, dy: -up.dy * depth)
    }

    /// 抬起的标签也要点得到：原来的标签面和抬满时的标签面合在一起（凸包）。
    func hitPolygon(rising rise: CGSize) -> [CGPoint] {
        guard rise != .zero else { return hitPolygon }
        let moved = hitPolygon.map { CGPoint(x: $0.x + rise.width, y: $0.y + rise.height) }
        return convexHull(hitPolygon + moved)
    }
}

/// 一组点的凸包（逆时针，Andrew 单调链）。
func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    guard sorted.count > 2 else { return sorted }
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    var lower: [CGPoint] = []
    for p in sorted {
        while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
            lower.removeLast()
        }
        lower.append(p)
    }
    var upper: [CGPoint] = []
    for p in sorted.reversed() {
        while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
            upper.removeLast()
        }
        upper.append(p)
    }
    return Array(lower.dropLast() + upper.dropLast())
}
