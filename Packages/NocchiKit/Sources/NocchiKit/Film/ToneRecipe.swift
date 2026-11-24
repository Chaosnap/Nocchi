import Foundation

/// 胶卷的「色调配方」：一组参数，运行时烘焙成 3D LUT。
///
/// 所有字段都有默认值，JSON 里只需要写与默认值不同的字段；
/// 默认配方是严格的恒等映射。
///
/// 处理顺序（`ToneProgram.apply`）：
/// 1. 线性空间：曝光 → 白平衡 → 串色 → 高光软肩（`highlightRolloff`）
/// 2. gamma 空间：反差 → 曲线（`curves`）→ HSL 色彩混合（`hsl`）→ 饱和度 / 肤色保护
///    → 分离色调 → 褪色（`fade`）→ 抬黑 / 压白
///
/// 黑白胶卷在第 1 步之后按 `monoMix` 在线性光里混成灰度，再走反差、`curves.master`、
/// `monoTone` 调色、分离色调与褪色（`curves.r/g/b`、`hsl`、饱和度对黑白无效）。
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
    /// 阴影染色（十六进制颜色；只取色相与浓度，亮度归一，`amount` 控制强度）。
    public var shadowTint: String?
    public var shadowTintAmount: Float
    /// 高光染色。
    public var highlightTint: String?
    public var highlightTintAmount: Float
    /// 黑白胶卷。
    public var monochrome: Bool
    /// 黑白混合权重（R, G, B，线性光），缺省使用 Rec.709。
    public var monoMix: [Float]?
    /// 黑白调色（如暖调、硒调）。
    public var monoTone: String?
    public var monoToneAmount: Float
    /// 曲线：胶片 S 曲线、趾部 / 肩部、通道交叉。nil = 不改变。
    public var curves: ToneCurves?
    /// 八个色相带的色彩混合器。nil = 不改变。
    public var hsl: HSLMixer?
    /// 阴影雾化（0…0.5）：黑位抬到 `fade`，越亮影响越小，高光不动。
    public var fade: Float
    /// 高光柔和过渡（0…1）：曝光 / 白平衡把高光推出 1 时用软肩压回，而不是硬裁切。
    public var highlightRolloff: Float
    /// 肤色保护（0…1）：橙色肤色带不跟随整体饱和度变化。
    public var skinProtect: Float

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
        monoToneAmount: Float = 0,
        curves: ToneCurves? = nil,
        hsl: HSLMixer? = nil,
        fade: Float = 0,
        highlightRolloff: Float = 0,
        skinProtect: Float = 0
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
        self.curves = curves
        self.hsl = hsl
        self.fade = fade
        self.highlightRolloff = highlightRolloff
        self.skinProtect = skinProtect
    }

    /// 恒等配方。
    public static let neutral = ToneRecipe()

    private enum CodingKeys: String, CodingKey {
        case exposure, temperature, tint, contrast, blackLift, whiteCap, saturation, crossTalk
        case shadowTint, shadowTintAmount, highlightTint, highlightTintAmount
        case monochrome, monoMix, monoTone, monoToneAmount
        case curves, hsl, fade, highlightRolloff, skinProtect
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
        curves = try c.decodeIfPresent(ToneCurves.self, forKey: .curves)
        hsl = try c.decodeIfPresent(HSLMixer.self, forKey: .hsl)
        fade = try c.decode(.fade, default: d.fade)
        highlightRolloff = try c.decode(.highlightRolloff, default: d.highlightRolloff)
        skinProtect = try c.decode(.skinProtect, default: d.skinProtect)
    }

    /// 把一个 sRGB 颜色按配方映射。批量处理（烘焙 LUT）时请用 `LUTBaker`，它只预处理一次配方。
    public func apply(to input: RGB) -> RGB {
        ToneProgram(self).apply(input)
    }
}

// MARK: - 曲线

/// 曲线上的一个控制点，JSON 里写成 `[x, y]`（0…1）。
public struct CurvePoint: Codable, Hashable, Sendable {
    public var x: Float
    public var y: Float

    public init(_ x: Float, _ y: Float) {
        self.x = x
        self.y = y
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Float.self)
        y = try c.decode(Float.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
    }
}

/// 每通道曲线：先过 `master`（三个通道一起），再分别过 `r` / `g` / `b`。
///
/// 控制点之间单调三次插值（`MonotoneCurve`，不会过冲）；没写 x = 0 / x = 1 的端点时
/// 自动补 (0, 0) / (1, 1)；空数组表示这一条不改变。
public struct ToneCurves: Codable, Hashable, Sendable {
    public var master: [CurvePoint]
    public var r: [CurvePoint]
    public var g: [CurvePoint]
    public var b: [CurvePoint]

    public init(master: [CurvePoint] = [], r: [CurvePoint] = [], g: [CurvePoint] = [], b: [CurvePoint] = []) {
        self.master = master
        self.r = r
        self.g = g
        self.b = b
    }

    public static let identity = ToneCurves()

    private enum CodingKeys: String, CodingKey {
        case master, r, g, b
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        master = try c.decode(.master, default: [])
        r = try c.decode(.r, default: [])
        g = try c.decode(.g, default: [])
        b = try c.decode(.b, default: [])
    }
}

// MARK: - HSL 色彩混合

/// 一个色相带的调整。
public struct HSLBand: Codable, Hashable, Sendable {
    /// 色相偏移（度）：正值沿色环正方向（红 → 黄 → 绿 → 青 → 蓝 → 品红）。
    public var hue: Float
    /// 饱和度倍数，1 为不变。
    public var saturation: Float
    /// 明度偏移（约 -0.3…0.3），0 为不变；对中间调、颜色明显的像素作用最强，灰色不受影响。
    public var luminance: Float

    public init(hue: Float = 0, saturation: Float = 1, luminance: Float = 0) {
        self.hue = hue
        self.saturation = saturation
        self.luminance = luminance
    }

    public static let neutral = HSLBand()

    public var isNeutral: Bool {
        abs(hue) < 0.0001 && abs(saturation - 1) < 0.0001 && abs(luminance) < 0.0001
    }

    private enum CodingKeys: String, CodingKey {
        case hue, saturation, luminance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hue = try c.decode(.hue, default: 0)
        saturation = try c.decode(.saturation, default: 1)
        luminance = try c.decode(.luminance, default: 0)
    }
}

/// 八个色相带（红、橙、黄、绿、青、蓝、紫、品红）的色彩混合器。
///
/// 色相带中心见 `ColorMath.hueBandCenters`；任意色相的调整量是相邻两个带按
/// cos² 窗平滑插值出来的（`ColorMath.hueBandWeights`），所以不会有色带断层。
public struct HSLMixer: Codable, Hashable, Sendable {
    public var red: HSLBand
    public var orange: HSLBand
    public var yellow: HSLBand
    public var green: HSLBand
    public var cyan: HSLBand
    public var blue: HSLBand
    public var purple: HSLBand
    public var magenta: HSLBand

    public init(
        red: HSLBand = .neutral,
        orange: HSLBand = .neutral,
        yellow: HSLBand = .neutral,
        green: HSLBand = .neutral,
        cyan: HSLBand = .neutral,
        blue: HSLBand = .neutral,
        purple: HSLBand = .neutral,
        magenta: HSLBand = .neutral
    ) {
        self.red = red
        self.orange = orange
        self.yellow = yellow
        self.green = green
        self.cyan = cyan
        self.blue = blue
        self.purple = purple
        self.magenta = magenta
    }

    public static let neutral = HSLMixer()

    /// 按色相顺序排列，与 `ColorMath.hueBandCenters` 一一对应。
    public var bands: [HSLBand] {
        [red, orange, yellow, green, cyan, blue, purple, magenta]
    }

    public var isNeutral: Bool {
        bands.allSatisfy { $0.isNeutral }
    }

    private enum CodingKeys: String, CodingKey {
        case red, orange, yellow, green, cyan, blue, purple, magenta
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decode(.red, default: .neutral)
        orange = try c.decode(.orange, default: .neutral)
        yellow = try c.decode(.yellow, default: .neutral)
        green = try c.decode(.green, default: .neutral)
        cyan = try c.decode(.cyan, default: .neutral)
        blue = try c.decode(.blue, default: .neutral)
        purple = try c.decode(.purple, default: .neutral)
        magenta = try c.decode(.magenta, default: .neutral)
    }
}

// MARK: - 编译后的配方

/// 预处理过的配方：颜色解析、曲线切线、色相带参数都只算一次，烘焙 LUT 时每个格点复用。
struct ToneProgram {
    let isIdentity: Bool
    let exposureGain: Float
    let whiteBalance: RGB?
    let crossTalk: Float
    let knee: Float
    let white: Float
    let contrast: Float
    let master: MonotoneCurve?
    let curveR: MonotoneCurve?
    let curveG: MonotoneCurve?
    let curveB: MonotoneCurve?
    let hslHue: [Float]?
    let hslSaturation: [Float]
    let hslLuminance: [Float]
    let saturation: Float
    let skinProtect: Float
    let shadowTint: RGB?
    let shadowAmount: Float
    let highlightTint: RGB?
    let highlightAmount: Float
    let monochrome: Bool
    let monoWeights: RGB
    let monoTone: RGB?
    let monoToneAmount: Float
    let fade: Float
    let blackLift: Float
    let whiteCap: Float

    init(_ recipe: ToneRecipe) {
        isIdentity = recipe == ToneRecipe.neutral
        exposureGain = recipe.exposure != 0 ? powf(2, recipe.exposure) : 1
        if recipe.temperature != 0 || recipe.tint != 0 {
            whiteBalance = RGB(
                1 + 0.10 * recipe.temperature + 0.02 * recipe.tint,
                1 - 0.07 * recipe.tint,
                1 - 0.13 * recipe.temperature + 0.02 * recipe.tint
            )
        } else {
            whiteBalance = nil
        }
        crossTalk = min(max(recipe.crossTalk, 0), 0.5)

        let rolloff = ColorMath.clamp01(recipe.highlightRolloff)
        if rolloff > 0 {
            let peak = exposureGain * (whiteBalance?.max() ?? 1)
            knee = 1 - 0.6 * rolloff
            white = max(peak, 1)
        } else {
            knee = 1
            white = 1
        }

        contrast = recipe.contrast
        let curves = recipe.curves ?? ToneCurves.identity
        master = ToneProgram.curve(curves.master)
        curveR = ToneProgram.curve(curves.r)
        curveG = ToneProgram.curve(curves.g)
        curveB = ToneProgram.curve(curves.b)

        if let mixer = recipe.hsl, !mixer.isNeutral {
            let bands = mixer.bands
            hslHue = bands.map { $0.hue }
            hslSaturation = bands.map { max($0.saturation, 0) }
            hslLuminance = bands.map { $0.luminance }
        } else {
            hslHue = nil
            hslSaturation = []
            hslLuminance = []
        }

        saturation = max(recipe.saturation, 0)
        skinProtect = ColorMath.clamp01(recipe.skinProtect)
        shadowTint = ToneProgram.toning(recipe.shadowTint)
        shadowAmount = max(recipe.shadowTintAmount, 0)
        highlightTint = ToneProgram.toning(recipe.highlightTint)
        highlightAmount = max(recipe.highlightTintAmount, 0)

        monochrome = recipe.monochrome
        if let mix = recipe.monoMix, mix.count == 3, mix[0] + mix[1] + mix[2] > 0.0001 {
            monoWeights = RGB(mix[0], mix[1], mix[2]) / (mix[0] + mix[1] + mix[2])
        } else {
            monoWeights = ColorMath.rec709Luma
        }
        monoTone = ToneProgram.toning(recipe.monoTone)
        monoToneAmount = max(recipe.monoToneAmount, 0)

        fade = min(max(recipe.fade, 0), 0.5)
        blackLift = recipe.blackLift
        whiteCap = recipe.whiteCap
    }

    private static func curve(_ points: [CurvePoint]) -> MonotoneCurve? {
        guard !points.isEmpty else { return nil }
        let curve = MonotoneCurve(points: points)
        return curve.isIdentity ? nil : curve
    }

    private static func toning(_ hex: String?) -> RGB? {
        guard let hex, let color = RGB(hex: hex) else { return nil }
        return ColorMath.toningColor(color)
    }

    func apply(_ input: RGB) -> RGB {
        let source = ColorMath.clamp01(input)
        if isIdentity { return source }

        // 1. 线性空间：曝光、白平衡、串色、高光软肩
        var lin = ColorMath.srgbToLinear(source)
        if exposureGain != 1 {
            lin *= exposureGain
        }
        if let gains = whiteBalance {
            lin *= gains
        }
        if crossTalk > 0 {
            let k = crossTalk
            lin = RGB(
                lin.x * (1 - k) + (lin.y + lin.z) * k * 0.5,
                lin.y * (1 - k) + (lin.x + lin.z) * k * 0.5,
                lin.z * (1 - k) + (lin.x + lin.y) * k * 0.5
            )
        }
        lin = RGB(shoulder(lin.x), shoulder(lin.y), shoulder(lin.z))

        if monochrome {
            return applyMonochrome(lin)
        }

        // 2. gamma 空间：反差 → 曲线 → HSL → 饱和度 / 肤色保护 → 分离色调 → 褪色
        var c = ColorMath.clamp01(ColorMath.linearToSRGB(lin))
        c = toneCurves(c)
        if let hue = hslHue {
            c = applyHSL(c, hue: hue)
        }
        c = applySaturation(c)
        c = splitTone(c)
        return finish(c)
    }

    /// 高光软肩：膝点以下不变，以上用有理函数压缩，最亮的可能输入正好落到 1。
    private func shoulder(_ x: Float) -> Float {
        let v = max(x, 0)
        guard v > knee else { return v }
        guard white > knee + 0.0001 else { return min(v, 1) }
        let a = (white - knee) / (1 - knee)
        let u = min((v - knee) / (white - knee), 1)
        return knee + (1 - knee) * (a * u / (1 + (a - 1) * u))
    }

    private func toneCurves(_ input: RGB) -> RGB {
        var c = input
        if abs(contrast - 1) > 0.0001 {
            c = RGB(
                ColorMath.contrastCurve(c.x, contrast),
                ColorMath.contrastCurve(c.y, contrast),
                ColorMath.contrastCurve(c.z, contrast)
            )
        }
        if let m = master {
            c = RGB(m.evaluate(c.x), m.evaluate(c.y), m.evaluate(c.z))
        }
        if let r = curveR {
            c.x = r.evaluate(c.x)
        }
        if let g = curveG {
            c.y = g.evaluate(c.y)
        }
        if let b = curveB {
            c.z = b.evaluate(c.z)
        }
        return ColorMath.clamp01(c)
    }

    private func applyHSL(_ input: RGB, hue shifts: [Float]) -> RGB {
        let chroma = input.max() - input.min()
        guard chroma > 1e-5 else { return input }
        let p = ColorMath.hsv(input)
        let band = ColorMath.hueBandWeights(p.h)
        let wu = band.upperWeight
        let wl = 1 - wu
        let dh = shifts[band.lower] * wl + shifts[band.upper] * wu
        let ds = hslSaturation[band.lower] * wl + hslSaturation[band.upper] * wu
        let dl = hslLuminance[band.lower] * wl + hslLuminance[band.upper] * wu

        var c = input
        let y0 = ColorMath.luminance(input)
        if abs(dh) > 0.001 {
            c = ColorMath.withLuminance(ColorMath.rgb(h: p.h + dh, s: p.s, v: p.v), y0)
        }
        if abs(ds - 1) > 0.0001 {
            c = ColorMath.scaleChroma(c, by: ds)
        }
        if abs(dl) > 0.00001 {
            let gate = ColorMath.smoothstep(0, 0.2, chroma)
            let y = ColorMath.luminance(c)
            c = ColorMath.withLuminance(c, y + dl * gate * 4 * y * (1 - y))
        }
        return ColorMath.clamp01(c)
    }

    private func applySaturation(_ c: RGB) -> RGB {
        var m = saturation
        if skinProtect > 0, abs(m - 1) > 0.0001 {
            m += (1 - m) * ColorMath.skinWeight(c) * skinProtect
        }
        guard abs(m - 1) > 0.0001 else { return c }
        return ColorMath.scaleChroma(c, by: m)
    }

    private func splitTone(_ input: RGB) -> RGB {
        var c = input
        let l = ColorMath.luminance(c)
        if let tint = shadowTint, shadowAmount > 0 {
            let w = (1 - l) * (1 - l)
            c = ColorMath.mix(c, ColorMath.softLight(c, tint), w * shadowAmount)
        }
        if let tint = highlightTint, highlightAmount > 0 {
            let w = l * l
            c = ColorMath.mix(c, ColorMath.softLight(c, tint), w * highlightAmount)
        }
        return ColorMath.clamp01(c)
    }

    private func finish(_ input: RGB) -> RGB {
        var c = input
        if fade > 0 {
            let inverse = RGB(repeating: 1) - c
            c += inverse * inverse * fade
        }
        if blackLift != 0 || whiteCap != 1 {
            c = RGB(repeating: blackLift) + c * (whiteCap - blackLift)
        }
        return ColorMath.clamp01(c)
    }

    private func applyMonochrome(_ lin: RGB) -> RGB {
        let y = ColorMath.clamp01((lin * monoWeights).sum())
        var g = ColorMath.linearToSRGB(y)
        if abs(contrast - 1) > 0.0001 {
            g = ColorMath.contrastCurve(g, contrast)
        }
        if let m = master {
            g = m.evaluate(g)
        }
        var c = RGB(repeating: ColorMath.clamp01(g))
        if let tone = monoTone, monoToneAmount > 0 {
            c = ColorMath.mix(c, ColorMath.softLight(c, tone), monoToneAmount)
        }
        c = splitTone(c)
        return finish(c)
    }
}
