import CoreGraphics
import Foundation
import simd

// 灯光模型：移植自 Typewriter Nocturne（所有者的终端项目，MIT 许可，
// © 2026 Typewriter Nocturne contributors）的 `app/nocturne/light-model.ts`。
//
// 板子是平面 z = 0（单位是板子上的点，原点左上，y 向下）。台灯是有一定高度的点光源，带一个边缘柔和的光锥；
// 太阳光和月光是平行光，从窗户照进来，在板子上投出窗格。照度遵循平方反比和朗伯余弦定律：
//
//     E = cone(θ) · max(0, n · l) / d²
//
// d 是到灯的距离，l 指向灯的单位向量，n 是板子的法线，θ 是偏离灯轴的角度。曝光让参考点正好收到 `intensity`，
// 再用 1 − e^(−E·k) 映射到 [0, 1)。原版在着色器里逐像素算；这里在 CPU 上按低分辨率算光照图，
// 灰尘粒子也按同一个模型点亮（见 App 里的 `CorkLightOverlay`）。

/// 光从哪里来。
public enum LightSource: String, Codable, CaseIterable, Sendable, Identifiable {
    /// 白天：太阳光斜着从窗户照进来，在板子上投出一块带窗格的光斑。
    case sunlight
    /// 夜里：一盏台灯，在板子上照出一团光（光锥 + 平方反比）。
    case deskLamp
    /// 夜里：月光从窗户照进来，冷色的窗格。
    case moonlight

    public var id: String { rawValue }

    /// 平行光（太阳、月亮）还是点光源（台灯）。
    public var isParallel: Bool { self != .deskLamp }
}

/// 平行光穿过的窗户在板子上的样子：中心、大小、窗格数、边缘柔和度（点）、斜切（光从侧面斜着来，窗格成平行四边形）。
public struct LightWindow: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var columns: Int
    public var rows: Int
    public var softness: Double
    public var skew: Double

    public init(x: Double, y: Double, width: Double, height: Double, columns: Int, rows: Int, softness: Double, skew: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.columns = columns
        self.rows = rows
        self.softness = softness
        self.skew = skew
    }
}

/// 一盏灯（或一扇窗）的全部几何：算照度用。
public struct LightRig: Equatable, Sendable {
    public var source: LightSource
    /// 台灯的位置（板子上的点，z = 离板子的高度）。
    public var position: SIMD3<Double>
    /// 台灯光轴的单位向量；平行光则是光前进的方向。
    public var direction: SIMD3<Double>
    public var cosOuter: Double
    public var cosInner: Double
    /// 照度在映射之前乘上的曝光。
    public var exposure: Double
    public var window: LightWindow

    public init(source: LightSource, position: SIMD3<Double>, direction: SIMD3<Double>, cosOuter: Double, cosInner: Double, exposure: Double, window: LightWindow) {
        self.source = source
        self.position = position
        self.direction = direction
        self.cosOuter = cosOuter
        self.cosInner = cosInner
        self.exposure = exposure
        self.window = window
    }
}

/// 摆灯要的参数（都是 0…1，位置是板子上的归一化坐标，原点左上）。
public struct LightPlacement: Equatable, Sendable {
    public var source: LightSource
    /// 灯（或窗）在哪一边：台灯就在这里的上方；太阳 / 月亮的光从这一边斜着照过来。
    public var x: Double
    public var y: Double
    /// 范围：台灯挂得多高（光斑多大）、窗户多大。
    public var reach: Double
    /// 柔和：光锥和窗格的边缘有多软。
    public var softness: Double
    /// 亮度。
    public var intensity: Double

    public init(source: LightSource, x: Double, y: Double, reach: Double, softness: Double, intensity: Double) {
        self.source = source
        self.x = x
        self.y = y
        self.reach = reach
        self.softness = softness
        self.intensity = intensity
    }
}

public enum LightModel {
    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        if edge0 == edge1 { return x < edge0 ? 0 : 1 }
        let t = min(1, max(0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    /// 光束角（度）→ 光锥半角的余弦。
    public static func spreadToCosine(_ degrees: Double) -> Double {
        cos(min(170, max(5, degrees)) * .pi / 360)
    }

    /// 窗格之间窗棂的半宽（点）。
    public static func barHalfWidth(paneWidth: Double, paneHeight: Double) -> Double {
        min(16, max(4, 0.04 * min(paneWidth, paneHeight)))
    }

    /// 沿一个方向，两根窗棂之间透过的光：窗棂上 0，窗格里 1，按 `soft` 模糊。
    static func between(_ offset: Double, cell: Double, bar: Double, soft: Double) -> Double {
        let t = offset / cell
        let fromBar = abs(t - t.rounded()) * cell
        return smoothstep(bar - soft, bar + soft, fromBar)
    }

    /// 板子上一点透过窗框的那部分平行光（0…1）。
    public static func windowGobo(_ rig: LightRig, x: Double, y: Double) -> Double {
        let w = rig.window
        let soft = max(0.5, w.softness)
        let sx = x - (y - w.y) * w.skew
        let dx = sx - w.x
        let dy = y - w.y
        let across = smoothstep(-soft, soft, w.width / 2 - abs(dx))
        let down = smoothstep(-soft, soft, w.height / 2 - abs(dy))
        let paneWidth = w.width / Double(max(1, w.columns))
        let paneHeight = w.height / Double(max(1, w.rows))
        let bar = barHalfWidth(paneWidth: paneWidth, paneHeight: paneHeight)
        let open = between(dx + w.width / 2, cell: paneWidth, bar: bar, soft: soft) * between(dy + w.height / 2, cell: paneHeight, bar: bar, soft: soft)
        return across * down * (0.3 + 0.7 * open)
    }

    /// 板子上一点的照度（曝光之前）。
    public static func irradiance(_ rig: LightRig, x: Double, y: Double, normal: SIMD3<Double> = SIMD3(0, 0, 1)) -> Double {
        if rig.source.isParallel {
            let toLight = -rig.direction
            return max(0, simd_dot(normal, toLight)) * windowGobo(rig, x: x, y: y)
        }
        let toPoint = SIMD3(x - rig.position.x, y - rig.position.y, -rig.position.z)
        let distanceSquared = max(1, simd_dot(toPoint, toPoint))
        let ray = toPoint / distanceSquared.squareRoot()
        let cone = smoothstep(rig.cosOuter, rig.cosInner, simd_dot(ray, rig.direction))
        let lambert = max(0, -simd_dot(normal, ray))
        return cone * lambert / distanceSquared
    }

    /// 曝光映射到 [0, 1)。
    public static func toneMap(_ value: Double) -> Double {
        1 - exp(-max(0, value))
    }

    /// 板子上一点的光量（0…1）。
    public static func lightAmount(_ rig: LightRig, x: Double, y: Double) -> Double {
        toneMap(irradiance(rig, x: x, y: y) * rig.exposure)
    }

    /// 按板子尺寸（点）和摆法搭一盏灯。
    public static func rig(_ placement: LightPlacement, size: CGSize) -> LightRig {
        let width = max(1, Double(size.width))
        let height = max(1, Double(size.height))
        let px = min(1, max(0, placement.x))
        let py = min(1, max(0, placement.y))
        let reach = min(1, max(0, placement.reach))
        let softness = min(1, max(0, placement.softness))
        // 亮度 0…1 → 参考点上的照度 0.4…2（原版的 0–2）。
        let target = 0.4 + 1.6 * min(1, max(0, placement.intensity))
        let spread = 74.0
        let halfAngle = acos(spreadToCosine(spread))
        let cosOuter = cos(halfAngle)
        let cosInner = cos(halfAngle * (1 - 0.85 * softness))
        let fullWindow = LightWindow(x: width / 2, y: height / 2, width: width, height: height, columns: 3, rows: 2, softness: 8, skew: 0)
        var rig = LightRig(source: placement.source, position: SIMD3(0, 0, 1), direction: SIMD3(0, 0, -1), cosOuter: cosOuter, cosInner: cosInner, exposure: 1, window: fullWindow)
        let reference: Double

        switch placement.source {
        case .deskLamp:
            // 台灯挂在这一点的前上方，越高光斑越大；光轴朝板子中间偏一点。
            let lamp = SIMD3(px * width, py * height, (0.32 + 0.68 * reach) * height)
            let aim = SIMD3(lamp.x + (width * 0.5 - lamp.x) * 0.3, lamp.y + (height * 0.5 - lamp.y) * 0.3, 0)
            rig.position = lamp
            rig.direction = simd_normalize(aim - lamp)
            reference = irradiance(rig, x: aim.x, y: aim.y)
        case .sunlight, .moonlight:
            // 平行光从这一边斜着照过来（太阳低一点，影子和窗格拉得更长）；窗格落在这一边和板子中间之间。
            let azimuth = atan2(0.5 - py, 0.5 - px)
            let elevation = (placement.source == .sunlight ? 32.0 : 40.0) * .pi / 180
            let direction = simd_normalize(SIMD3(cos(azimuth) * cos(elevation), sin(azimuth) * cos(elevation), -sin(elevation)))
            let columns = placement.source == .sunlight ? 3 : 2
            let rows = 2
            let pane = max(40, min(width * 0.62, height * 0.7) * (0.45 + 0.75 * reach) / 2)
            let slant = min(30, max(-30, (px - 0.5) * 50)) * .pi / 180
            rig.direction = direction
            rig.window = LightWindow(
                x: (px + (0.5 - px) * 0.5) * width,
                y: (py + (0.5 - py) * 0.5) * height,
                width: pane * Double(columns),
                height: pane * Double(rows),
                columns: columns,
                rows: rows,
                softness: 4 + 40 * softness,
                skew: tan(slant)
            )
            reference = max(0, -direction.z)
        }
        rig.exposure = reference > 0 ? target / reference : 0
        return rig
    }
}
