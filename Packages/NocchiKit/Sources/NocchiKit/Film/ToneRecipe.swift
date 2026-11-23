import Foundation

/// 胶卷的「色调配方」：一组参数，运行时烘焙成 3D LUT。
///
/// 所有字段都有默认值，JSON 里只需要写与默认值不同的字段；
/// 默认配方是严格的恒等映射。
public struct ToneRecipe: Codable, Hashable, Sendable {
    /// 曝光补偿（档）。
    public var exposure: Float
    /// 色温：-1 偏冷（蓝），+1 偏暖（黄）。
    public var temperature: Float
    /// 色调：-1 偏绿，+1 偏品红。
    public var tint: Float
    /// 对比度曲线强度，1 为不变。
    public var contrast: Float
    /// 黑位抬升（褪色感），0…0.3。
    public var blackLift: Float
    /// 白位压低，0.7…1。
    public var whiteCap: Float
    /// 饱和度，1 为不变。
    public var saturation: Float
    /// 染料串色（通道互相渗透），0…0.2。
    public var crossTalk: Float
    /// 阴影染色（柔光混合的十六进制颜色，`#808080` 为中性）。
    public var shadowTint: String?
    public var shadowTintAmount: Float
    /// 高光染色。
    public var highlightTint: String?
    public var highlightTintAmount: Float
    /// 黑白胶卷。
    public var monochrome: Bool
    /// 黑白混合权重（R, G, B），缺省使用 Rec.709。
    public var monoMix: [Float]?
    /// 黑白调色（如暖调、硒调）。
    public var monoTone: String?
    public var monoToneAmount: Float

    public init(
        exposure: Float = 0,
        temperature: Float = 0,
        tint: Float = 0,
        contrast: Float = 1,
        blackLift: Float = 0,
        whiteCap: Float = 1,
        saturation: Float = 1,
        crossTalk: Float = 0,
        shadowTint: String? = nil,
        shadowTintAmount: Float = 0,
        highlightTint: String? = nil,
        highlightTintAmount: Float = 0,
        monochrome: Bool = false,
        monoMix: [Float]? = nil,
        monoTone: String? = nil,
        monoToneAmount: Float = 0
    ) {
        self.exposure = exposure
        self.temperature = temperature
        self.tint = tint
        self.contrast = contrast
        self.blackLift = blackLift
        self.whiteCap = whiteCap
        self.saturation = saturation
        self.crossTalk = crossTalk
        self.shadowTint = shadowTint
        self.shadowTintAmount = shadowTintAmount
        self.highlightTint = highlightTint
        self.highlightTintAmount = highlightTintAmount
        self.monochrome = monochrome
        self.monoMix = monoMix
        self.monoTone = monoTone
        self.monoToneAmount = monoToneAmount
    }

    /// 恒等配方。
    public static let neutral = ToneRecipe()

    private enum CodingKeys: String, CodingKey {
        case exposure, temperature, tint, contrast, blackLift, whiteCap, saturation, crossTalk
        case shadowTint, shadowTintAmount, highlightTint, highlightTintAmount
        case monochrome, monoMix, monoTone, monoToneAmount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ToneRecipe()
        exposure = try c.decode(.exposure, default: d.exposure)
        temperature = try c.decode(.temperature, default: d.temperature)
        tint = try c.decode(.tint, default: d.tint)
        contrast = try c.decode(.contrast, default: d.contrast)
        blackLift = try c.decode(.blackLift, default: d.blackLift)
        whiteCap = try c.decode(.whiteCap, default: d.whiteCap)
        saturation = try c.decode(.saturation, default: d.saturation)
        crossTalk = try c.decode(.crossTalk, default: d.crossTalk)
        shadowTint = try c.decodeIfPresent(String.self, forKey: .shadowTint)
        shadowTintAmount = try c.decode(.shadowTintAmount, default: d.shadowTintAmount)
        highlightTint = try c.decodeIfPresent(String.self, forKey: .highlightTint)
        highlightTintAmount = try c.decode(.highlightTintAmount, default: d.highlightTintAmount)
        monochrome = try c.decode(.monochrome, default: d.monochrome)
        monoMix = try c.decodeIfPresent([Float].self, forKey: .monoMix)
        monoTone = try c.decodeIfPresent(String.self, forKey: .monoTone)
        monoToneAmount = try c.decode(.monoToneAmount, default: d.monoToneAmount)
    }

    /// 把一个 sRGB 颜色按配方映射。烘焙 LUT 时对每个格点调用一次。
    public func apply(to input: RGB) -> RGB {
        // 1. 线性空间：曝光、白平衡、串色
        var lin = ColorMath.srgbToLinear(ColorMath.clamp01(input))
        if exposure != 0 {
            lin *= powf(2, exposure)
        }
        if temperature != 0 || tint != 0 {
            let gains = RGB(
                1 + 0.10 * temperature + 0.02 * tint,
                1 - 0.07 * tint,
                1 - 0.13 * temperature + 0.02 * tint
            )
            lin *= gains
        }
        if crossTalk > 0 {
            let k = min(crossTalk, 0.5)
            lin = RGB(
                lin.x * (1 - k) + (lin.y + lin.z) * k * 0.5,
                lin.y * (1 - k) + (lin.x + lin.z) * k * 0.5,
                lin.z * (1 - k) + (lin.x + lin.y) * k * 0.5
            )
        }

        // 2. 回到 gamma 空间做曲线与色彩
        var c = ColorMath.clamp01(ColorMath.linearToSRGB(lin))
        if abs(contrast - 1) > 0.0001 {
            c = RGB(
                ColorMath.contrastCurve(c.x, contrast),
                ColorMath.contrastCurve(c.y, contrast),
                ColorMath.contrastCurve(c.z, contrast)
            )
        }

        if monochrome {
            var weights = ColorMath.rec709Luma
            if let mix = monoMix, mix.count == 3 {
                let total = max(mix[0] + mix[1] + mix[2], 0.0001)
                weights = RGB(mix[0], mix[1], mix[2]) / total
            }
            let l = ColorMath.clamp01((c * weights).sum())
            c = RGB(repeating: l)
            if monoToneAmount > 0, let hex = monoTone, let tone = RGB(hex: hex) {
                c = ColorMath.mix(c, ColorMath.softLight(c, tone), monoToneAmount)
            }
        } else {
            if abs(saturation - 1) > 0.0001 {
                let l = ColorMath.luminance(c)
                c = RGB(repeating: l) + (c - RGB(repeating: l)) * saturation
                c = ColorMath.clamp01(c)
            }
            let l = ColorMath.luminance(c)
            if shadowTintAmount > 0, let hex = shadowTint, let tint = RGB(hex: hex) {
                let w = (1 - l) * (1 - l)
                c = ColorMath.mix(c, ColorMath.softLight(c, tint), w * shadowTintAmount)
            }
            if highlightTintAmount > 0, let hex = highlightTint, let tint = RGB(hex: hex) {
                let w = l * l
                c = ColorMath.mix(c, ColorMath.softLight(c, tint), w * highlightTintAmount)
            }
        }

        // 3. 褪色：抬黑、压白
        if blackLift != 0 || whiteCap != 1 {
            c = RGB(repeating: blackLift) + c * (whiteCap - blackLift)
        }
        return ColorMath.clamp01(c)
    }
}
