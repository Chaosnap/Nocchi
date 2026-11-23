import CoreGraphics
import CoreImage
import Foundation
import ImageIO

/// 一次冲印的参数。
public struct ProcessOptions: Sendable {
    /// 目标比例（宽 / 高）。nil 表示保持原比例。
    public var targetAspect: CGFloat?
    /// 裁剪焦点（归一化，原点左下）。
    public var focus: CGPoint?
    /// 输出长边像素上限。
    public var maxLongEdge: CGFloat
    /// 自拍镜像。
    public var mirror: Bool
    /// 颗粒、漏光的随机种子。
    public var seed: UInt64
    /// 额外曝光（档），例如大头贴机的闪光过曝。
    public var exposureBias: Float

    public init(
        targetAspect: CGFloat? = nil,
        focus: CGPoint? = nil,
        maxLongEdge: CGFloat = 1600,
        mirror: Bool = false,
        seed: UInt64 = 1,
        exposureBias: Float = 0
    ) {
        self.targetAspect = targetAspect
        self.focus = focus
        self.maxLongEdge = maxLongEdge
        self.mirror = mirror
        self.seed = seed
        self.exposureBias = exposureBias
    }
}

/// 「暗房」：把输入图像冲印成某一卷胶卷的样子。
///
/// 管线：镜像 → 裁剪 → 缩放 → 曝光 → 3D LUT 色调 → Halation → 柔焦 → 漏光 → 暗角 → 颗粒。
/// 色块（Blotch）单独一步，因为它会在显影过程中被「甩」出来。
/// 同一个 seed 永远得到同一张图，预览、动画与导出保持一致。
public final class FilmProcessor: @unchecked Sendable {
    public let context: CIContext
    /// 用户导入的 `.cube` 所在目录。
    public var lutDirectory: URL?

    private let lock = NSLock()
    private var cubeCache: [String: ColorCube] = [:]
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    public init(context: CIContext? = nil, lutDirectory: URL? = nil) {
        self.context = context ?? FilmProcessor.makeContext()
        self.lutDirectory = lutDirectory
    }

    public static func makeContext(softwareRenderer: Bool = false) -> CIContext {
        var options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .cacheIntermediates: false
        ]
        if softwareRenderer {
            options[.useSoftwareRenderer] = true
        }
        return CIContext(options: options)
    }

    // MARK: - Public API

    /// 冲印一张图，返回 8-bit sRGB 位图。
    public func process(_ input: CGImage, stock: FilmStock, options: ProcessOptions) -> CGImage? {
        let image = pipeline(CIImage(cgImage: input), stock: stock, options: options)
        return render(image)
    }

    /// 在已冲印的底片上叠加色块。
    public func applyingBlotches(_ blotches: [Blotch], to negative: CGImage) -> CGImage? {
        guard !blotches.isEmpty else { return negative }
        let base = CIImage(cgImage: negative)
        return render(applyBlotches(base, blotches: blotches, extent: base.extent))
    }

    /// 取（或烘焙）胶卷的颜色立方体。
    public func cube(for stock: FilmStock) -> ColorCube {
        let key = stock.lookKey
        lock.lock()
        if let cached = cubeCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var cube: ColorCube?
        if let file = stock.lutFile, let dir = lutDirectory {
            let url = dir.appendingPathComponent(file)
            if let lut = try? CubeLUT(contentsOf: url) {
                cube = lut.colorCube(intensity: stock.lutIntensity)
            }
        }
        let result = cube ?? LUTBaker.bake(stock.tone, intensity: stock.lutFile == nil ? stock.lutIntensity : 1)

        lock.lock()
        cubeCache[key] = result
        lock.unlock()
        return result
    }

    /// 完整管线（不含色块），输出的 extent 原点为 (0, 0)、尺寸为整数。
    public func pipeline(_ source: CIImage, stock: FilmStock, options: ProcessOptions) -> CIImage {
        var image = source
        if options.mirror {
            image = image.oriented(.upMirrored)
        }
        image = moveToOrigin(image)
        image = crop(image, aspect: options.targetAspect, focus: options.focus)
        image = scale(image, maxLongEdge: options.maxLongEdge)
        let extent = image.extent

        if options.exposureBias != 0 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: options.exposureBias])
        }
        image = applyCube(image, cube: cube(for: stock))
        let fx = stock.effects
        image = applyHalation(image, amount: fx.halation, extent: extent)
        image = applyBloom(image, amount: fx.bloom, extent: extent)
        image = applyLightLeak(image, amount: fx.lightLeak, extent: extent, seed: options.seed)
        image = applyVignette(image, amount: fx.vignette, extent: extent)
        image = applyGrain(image, amount: fx.grain, size: fx.grainSize, extent: extent, seed: options.seed)
        return image.cropped(to: extent)
    }

    // MARK: - Rendering

    private func render(_ image: CIImage) -> CGImage? {
        let extent = image.extent
        guard extent.width >= 1, extent.height >= 1, extent.width.isFinite, extent.height.isFinite else { return nil }
        return context.createCGImage(image, from: extent, format: .RGBA8, colorSpace: sRGB)
    }

    // MARK: - Geometry

    private func moveToOrigin(_ image: CIImage) -> CIImage {
        let e = image.extent
        guard e.minX != 0 || e.minY != 0 else { return image }
        return image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
    }

    private func crop(_ image: CIImage, aspect: CGFloat?, focus: CGPoint?) -> CIImage {
        guard let aspect, aspect > 0 else { return image }
        let rect = CropMath.cropRect(imageSize: image.extent.size, aspect: aspect, focus: focus ?? CGPoint(x: 0.5, y: 0.5))
        return image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }

    private func scale(_ image: CIImage, maxLongEdge: CGFloat) -> CIImage {
        var out = image
        let size = image.extent.size
        let longEdge = max(size.width, size.height)
        if maxLongEdge > 0, longEdge > maxLongEdge {
            let s = maxLongEdge / longEdge
            out = image.applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: s,
                kCIInputAspectRatioKey: 1.0
            ])
        }
        out = moveToOrigin(out)
        let w = max(1, floor(out.extent.width))
        let h = max(1, floor(out.extent.height))
        return out.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    }

    // MARK: - Color

    private func applyCube(_ image: CIImage, cube: ColorCube) -> CIImage {
        image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": cube.dimension,
            "inputCubeData": cube.data,
            "inputColorSpace": sRGB
        ])
    }

    // MARK: - Effects

    private func lumaMatrix(_ image: CIImage) -> CIImage {
        let w = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": w,
            "inputGVector": w,
            "inputBVector": w,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
    }

    /// 高光周围的红橙色光晕。
    private func applyHalation(_ image: CIImage, amount: Float, extent: CGRect) -> CIImage {
        guard amount > 0.001 else { return image }
        let minDim = min(extent.width, extent.height)
        let mask = lumaMatrix(image).applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0),
            "inputPoint1": CIVector(x: 0.5, y: 0),
            "inputPoint2": CIVector(x: 0.72, y: 0.12),
            "inputPoint3": CIVector(x: 0.88, y: 0.55),
            "inputPoint4": CIVector(x: 1, y: 1)
        ])
        let a = CGFloat(amount)
        let glow = mask.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: minDim * 0.022])
            .cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.95 * a, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0.28 * a, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0.14 * a, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
        return glow.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
            .cropped(to: extent)
    }

    /// 柔焦。
    private func applyBloom(_ image: CIImage, amount: Float, extent: CGRect) -> CIImage {
        guard amount > 0.001 else { return image }
        let minDim = min(extent.width, extent.height)
        return image.clampedToExtent()
            .applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: minDim * 0.018,
                kCIInputIntensityKey: CGFloat(amount) * 0.8
            ])
            .cropped(to: extent)
    }

    /// 漏光：从某条边渗进来的暖色光。
    private func applyLightLeak(_ image: CIImage, amount: Float, extent: CGRect, seed: UInt64) -> CIImage {
        guard amount > 0.001 else { return image }
        var rng = SeededRandom(seed: seed ^ 0x1EA4_C0DE)
        let w = extent.width, h = extent.height
        let t = CGFloat(rng.range(0.15, 0.85))
        let center: CGPoint
        switch rng.index(4) {
        case 0: center = CGPoint(x: extent.minX, y: extent.minY + h * t)
        case 1: center = CGPoint(x: extent.maxX, y: extent.minY + h * t)
        case 2: center = CGPoint(x: extent.minX + w * t, y: extent.maxY)
        default: center = CGPoint(x: extent.minX + w * t, y: extent.minY)
        }
        let palette: [(CGFloat, CGFloat, CGFloat)] = [(1.0, 0.42, 0.12), (1.0, 0.24, 0.18), (1.0, 0.72, 0.28)]
        let c = palette[rng.index(palette.count)]
        let radius = max(w, h) * CGFloat(rng.range(0.35, 0.6))
        let alpha = min(1, CGFloat(amount) * 0.9)
        guard let gradient = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: center.x, y: center.y),
            "inputRadius0": radius * 0.08,
            "inputRadius1": radius,
            "inputColor0": CIColor(red: c.0, green: c.1, blue: c.2, alpha: alpha),
            "inputColor1": CIColor(red: c.0, green: c.1, blue: c.2, alpha: 0)
        ])?.outputImage else { return image }
        return gradient.cropped(to: extent)
            .applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
            .cropped(to: extent)
    }

    /// 暗角。
    private func applyVignette(_ image: CIImage, amount: Float, extent: CGRect) -> CIImage {
        guard amount > 0.001 else { return image }
        let radius = hypot(extent.width, extent.height) / 2
        let edge = max(0.2, 1 - CGFloat(amount) * 0.45)
        guard let gradient = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": radius * 0.42,
            "inputRadius1": radius * 1.02,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
            "inputColor1": CIColor(red: edge, green: edge, blue: edge, alpha: 1)
        ])?.outputImage else { return image }
        return gradient.cropped(to: extent)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: image])
            .cropped(to: extent)
    }

    /// 颗粒：以 0.5 为中性的单色噪声做柔光混合。
    private func applyGrain(_ image: CIImage, amount: Float, size: Float, extent: CGRect, seed: UInt64) -> CIImage {
        guard amount > 0.001, let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }
        let ox = CGFloat(seed % 2048)
        let oy = CGFloat((seed >> 11) % 2048)
        var grain = noise.transformed(by: CGAffineTransform(translationX: -ox, y: -oy))
        let s = CGFloat(max(0.5, size))
        if abs(s - 1) > 0.01 {
            grain = grain.transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        let k = CGFloat(amount) * 0.32
        let bias = 0.5 - k / 2
        grain = grain.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 1)
        ])
        if s > 1.2 {
            grain = grain.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: (s - 1) * 0.45])
        }
        return grain.cropped(to: extent)
            .applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
            .cropped(to: extent)
    }

    /// 色块：亮斑用滤色，暗斑用正片叠底。
    private func applyBlotches(_ image: CIImage, blotches: [Blotch], extent: CGRect) -> CIImage {
        var out = image
        for blotch in blotches {
            let rgb = RGB(hex: blotch.color) ?? RGB(0.8, 0.85, 0.85)
            let r = CGFloat(blotch.radius) * extent.width
            let cx = extent.minX + CGFloat(blotch.x) * extent.width
            let cy = extent.minY + (1 - CGFloat(blotch.y)) * extent.height
            let alpha = CGFloat(min(max(blotch.strength, 0), 1))
            let color0 = CIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: alpha)
            let color1 = CIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 0)
            guard let gradient = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: cx, y: cy),
                "inputRadius0": r * 0.3,
                "inputRadius1": r,
                "inputColor0": color0,
                "inputColor1": color1
            ])?.outputImage else { continue }
            let mode = blotch.kind == .pale ? "CIScreenBlendMode" : "CIMultiplyBlendMode"
            out = gradient.cropped(to: extent)
                .applyingFilter(mode, parameters: [kCIInputBackgroundImageKey: out])
                .cropped(to: extent)
        }
        return out
    }
}
