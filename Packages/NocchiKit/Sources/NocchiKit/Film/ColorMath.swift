import Foundation

/// RGB 三通道浮点颜色（0…1）。
public typealias RGB = SIMD3<Float>

/// 胶卷配方用到的颜色数学。全部是纯函数，方便单元测试。
///
/// `scripts/film/preview_looks.py` 里有一份逐行对应的 numpy 实现（用来离线看效果），
/// 改这里的数学时记得同步改那边。
public enum ColorMath {
    /// Rec.709 亮度权重。
    public static let rec709Luma = RGB(0.2126, 0.7152, 0.0722)

    public static func srgbToLinear(_ c: Float) -> Float {
        c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
    }

    public static func linearToSRGB(_ c: Float) -> Float {
        let v = max(0, c)
        return v <= 0.0031308 ? v * 12.92 : 1.055 * powf(v, 1 / 2.4) - 0.055
    }

    public static func srgbToLinear(_ c: RGB) -> RGB {
        RGB(srgbToLinear(c.x), srgbToLinear(c.y), srgbToLinear(c.z))
    }

    public static func linearToSRGB(_ c: RGB) -> RGB {
        RGB(linearToSRGB(c.x), linearToSRGB(c.y), linearToSRGB(c.z))
    }

    public static func luminance(_ c: RGB) -> Float {
        (c * rec709Luma).sum()
    }

    public static func clamp01(_ x: Float) -> Float {
        min(max(x, 0), 1)
    }

    public static func clamp01(_ c: RGB) -> RGB {
        c.clamped(lowerBound: RGB(repeating: 0), upperBound: RGB(repeating: 1))
    }

    public static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    public static func mix(_ a: RGB, _ b: RGB, _ t: Float) -> RGB {
        a + (b - a) * t
    }

    /// Pegtop soft light：blend = 0.5 时保持原色。
    public static func softLight(_ base: Float, _ blend: Float) -> Float {
        (1 - 2 * blend) * base * base + 2 * blend * base
    }

    public static func softLight(_ base: RGB, _ blend: RGB) -> RGB {
        RGB(softLight(base.x, blend.x), softLight(base.y, blend.y), softLight(base.z, blend.z))
    }

    /// 以 0.5 为支点、保持 0 与 1 不动的对比度曲线。k > 1 增加对比，k < 1 降低对比。
    public static func contrastCurve(_ x: Float, _ k: Float) -> Float {
        let x = clamp01(x)
        guard k > 0, abs(k - 1) > 0.0001 else { return x }
        let a = powf(x, k)
        let b = powf(1 - x, k)
        let sum = a + b
        return sum > 0 ? a / sum : x
    }

    // MARK: - 色相 / 饱和度

    /// RGB → HSV。h 为度（0..<360，灰色为 0），s、v 为 0…1。
    public static func hsv(_ c: RGB) -> (h: Float, s: Float, v: Float) {
        let maxc = c.max()
        let minc = c.min()
        let d = maxc - minc
        let s: Float = maxc > 0 ? d / maxc : 0
        guard d > 1e-7 else { return (0, s, maxc) }
        var h: Float
        if maxc == c.x {
            h = 60 * ((c.y - c.z) / d)
        } else if maxc == c.y {
            h = 60 * ((c.z - c.x) / d + 2)
        } else {
            h = 60 * ((c.x - c.y) / d + 4)
        }
        if h < 0 { h += 360 }
        if h >= 360 { h -= 360 }
        return (h, s, maxc)
    }

    /// HSV → RGB（h 为度，可以超出 0..<360）。
    public static func rgb(h: Float, s: Float, v: Float) -> RGB {
        guard h.isFinite, s.isFinite, v.isFinite else { return RGB(repeating: v.isFinite ? v : 0) }
        var hh = h.truncatingRemainder(dividingBy: 360)
        if hh < 0 { hh += 360 }
        let chroma = v * s
        let hp = hh / 60
        let x = chroma * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let base: RGB
        switch Int(hp) {
        case 0: base = RGB(chroma, x, 0)
        case 1: base = RGB(x, chroma, 0)
        case 2: base = RGB(0, chroma, x)
        case 3: base = RGB(0, x, chroma)
        case 4: base = RGB(x, 0, chroma)
        default: base = RGB(chroma, 0, x)
        }
        return base + RGB(repeating: v - chroma)
    }

    /// 八个色相带的中心（度）：红、橙、黄、绿、青、蓝、紫、品红（与 `HSLMixer.bands` 顺序一致）。
    public static let hueBandCenters: [Float] = [0, 30, 60, 120, 180, 240, 270, 300]

    /// 某个色相夹在哪两个相邻色相带之间，以及靠上那个带的权重。
    ///
    /// 两个带的权重是 cos² / sin² 窗：和永远为 1，在带中心处导数为 0，
    /// 所以色相带之间是平滑过渡，不会出现断层。
    public static func hueBandWeights(_ hue: Float) -> (lower: Int, upper: Int, upperWeight: Float) {
        var h = hue.truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        let centers = hueBandCenters
        var lower = centers.count - 1
        for i in 0..<centers.count where centers[i] <= h {
            lower = i
        }
        let upper = (lower + 1) % centers.count
        let start = centers[lower]
        let end: Float = upper == 0 ? 360 : centers[upper]
        let t = clamp01((h - start) / (end - start))
        let s = sinf(t * Float.pi / 2)
        return (lower, upper, s * s)
    }

    /// 把颜色的亮度（Rec.709）改成 target，保持色相：变亮时朝白色混合，变暗时等比例缩小。结果不会越界。
    public static func withLuminance(_ c: RGB, _ target: Float) -> RGB {
        let y = luminance(c)
        let t = clamp01(target)
        if t > y {
            guard y < 0.99999 else { return c }
            let k = (t - y) / (1 - y)
            return c + (RGB(repeating: 1) - c) * k
        }
        if t < y {
            guard y > 0.00001 else { return c }
            return c * (t / y)
        }
        return c
    }

    /// 保持亮度地缩放色度（饱和度）。m < 1 朝灰色收；m > 1 时平滑地逼近色域边界，不会硬切，
    /// 本来就很饱和的颜色几乎不再变，避免红花、蓝天糊成一片。
    public static func scaleChroma(_ c: RGB, by m: Float) -> RGB {
        let y = luminance(c)
        let gray = RGB(repeating: y)
        let d = c - gray
        if m <= 1 {
            return clamp01(gray + d * max(m, 0))
        }
        var limit = Float.greatestFiniteMagnitude
        for i in 0..<3 {
            let di = d[i]
            if di > 1e-6 {
                limit = min(limit, (1 - y) / di)
            } else if di < -1e-6 {
                limit = min(limit, -y / di)
            }
        }
        guard limit < 1e6 else { return c }
        let room = max(limit - 1, 0)
        guard room > 1e-6 else { return c }
        let k = 1 + room * (1 - expf(-(m - 1) / room))
        return clamp01(gray + d * k)
    }

    /// 肤色权重（0…1）：橙色色相（约 12°–38° 全权重）、中等饱和、不太暗。
    /// `skinProtect` 用它让肤色少跟随整体饱和度变化。
    public static func skinWeight(_ c: RGB) -> Float {
        let p = hsv(c)
        guard p.s > 0.02, p.v > 0.08 else { return 0 }
        let h = p.h > 180 ? p.h - 360 : p.h
        let hueGate = smoothstep(-5, 12, h) * (1 - smoothstep(38, 55, h))
        let satGate = smoothstep(0.06, 0.16, p.s) * (1 - smoothstep(0.6, 0.85, p.s))
        let valueGate = smoothstep(0.12, 0.3, p.v)
        return hueGate * satGate * valueGate
    }

    /// 调色用的颜色：亮度归一到 0.5，只保留色相与浓度。柔光混合时它只改颜色、不改明暗。
    public static func toningColor(_ c: RGB) -> RGB {
        clamp01(c - RGB(repeating: luminance(c)) + RGB(repeating: 0.5))
    }
}

/// 单调三次插值曲线（Fritsch–Carlson）：经过每个控制点，相邻点之间不过冲；
/// 控制点单调时曲线也单调。没写 x = 0 / x = 1 的端点时自动补 (0, 0) / (1, 1)。
public struct MonotoneCurve: Hashable, Sendable {
    public let xs: [Float]
    public let ys: [Float]
    /// 每个控制点的切线斜率。
    public let tangents: [Float]

    public init(points: [CurvePoint]) {
        let sorted = points
            .map { CurvePoint(ColorMath.clamp01($0.x), ColorMath.clamp01($0.y)) }
            .sorted { $0.x < $1.x }
        var unique: [CurvePoint] = []
        for p in sorted {
            if let last = unique.last, abs(last.x - p.x) < 1e-5 {
                unique[unique.count - 1] = p
            } else {
                unique.append(p)
            }
        }
        if unique.isEmpty || unique[0].x > 1e-5 {
            unique.insert(CurvePoint(0, 0), at: 0)
        }
        if unique[unique.count - 1].x < 1 - 1e-5 {
            unique.append(CurvePoint(1, 1))
        }

        let n = unique.count
        let x = unique.map(\.x)
        let y = unique.map(\.y)
        var secant = [Float](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            secant[i] = (y[i + 1] - y[i]) / (x[i + 1] - x[i])
        }
        var m = [Float](repeating: 0, count: n)
        m[0] = secant[0]
        m[n - 1] = secant[n - 2]
        for i in 1..<(n - 1) {
            m[i] = secant[i - 1] * secant[i] <= 0 ? 0 : (secant[i - 1] + secant[i]) / 2
        }
        for i in 0..<(n - 1) {
            if abs(secant[i]) < 1e-9 {
                m[i] = 0
                m[i + 1] = 0
                continue
            }
            let a = m[i] / secant[i]
            let b = m[i + 1] / secant[i]
            let s = a * a + b * b
            if s > 9 {
                let t = 3 / sqrtf(s)
                m[i] = t * a * secant[i]
                m[i + 1] = t * b * secant[i]
            }
        }
        xs = x
        ys = y
        tangents = m
    }

    /// 控制点都在对角线上（恒等）。
    public var isIdentity: Bool {
        zip(xs, ys).allSatisfy { abs($0 - $1) < 1e-5 }
    }

    public func evaluate(_ value: Float) -> Float {
        let n = xs.count
        if value <= xs[0] { return ys[0] }
        if value >= xs[n - 1] { return ys[n - 1] }
        var i = 0
        while i < n - 2 && value > xs[i + 1] {
            i += 1
        }
        let h = xs[i + 1] - xs[i]
        let t = (value - xs[i]) / h
        let t2 = t * t
        let t3 = t2 * t
        let h00 = 2 * t3 - 3 * t2 + 1
        let h10 = t3 - 2 * t2 + t
        let h01 = 3 * t2 - 2 * t3
        let h11 = t3 - t2
        let left = h00 * ys[i] + h10 * h * tangents[i]
        let right = h01 * ys[i + 1] + h11 * h * tangents[i + 1]
        return left + right
    }
}

public extension SIMD3 where Scalar == Float {
    /// 从 `#RRGGBB` 解析颜色。
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            Float((value >> 16) & 0xFF) / 255,
            Float((value >> 8) & 0xFF) / 255,
            Float(value & 0xFF) / 255
        )
    }

    /// `#RRGGBB` 字符串。
    var hexString: String {
        func byte(_ v: Float) -> Int { Int((Swift.min(Swift.max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(x), byte(y), byte(z))
    }
}
