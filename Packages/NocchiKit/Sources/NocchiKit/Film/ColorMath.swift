import Foundation

/// RGB 三通道浮点颜色（0…1）。
public typealias RGB = SIMD3<Float>

/// 胶卷配方用到的颜色数学。全部是纯函数，方便单元测试。
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
