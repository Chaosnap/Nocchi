import CoreGraphics
import NocchiKit
import SwiftUI

/// 一张即显相片的纸面（两端共用）。
///
/// 层次（从下到上）：
/// 1. 底层：`PhotoComposer.renderBase`——相纸、模板底纹（毛边、牛皮纸、黑卡纸……）
/// 2. 图像窗口：显影动画 + 光面高光，按模板的窗口形状裁切（心形、矩形）
/// 3. 上层：`PhotoComposer.renderOverlay`——窗口内凹阴影、模板图样、题字 / 地点 / 标签、贴纸、笔画
/// 4. 正在写的一笔、卷曲明暗、纸边倒角高光（屏幕专属）
///
/// 底层和上层就是导出成片用的同一套渲染，所以显影完成时屏幕上看到的和成片一样（光面高光除外）。
public struct PrintSurface: View {
    public let record: PhotoRecord
    public let images: [CGImage]
    public let visuals: [DevelopmentVisual]
    public let paper: PaperStyle
    public let width: CGFloat
    public var liveStroke: InkStroke?
    /// 光面高光的位置（0…1，随相片在屏幕上的位置变化）。
    public var sheen: CGPoint
    public var showsGloss: Bool

    public init(
        record: PhotoRecord,
        images: [CGImage],
        visuals: [DevelopmentVisual],
        paper: PaperStyle,
        width: CGFloat,
        liveStroke: InkStroke? = nil,
        sheen: CGPoint = CGPoint(x: 0.32, y: 0.22),
        showsGloss: Bool = true
    ) {
        self.record = record
        self.images = images
        self.visuals = visuals
        self.paper = paper
        self.width = width
        self.liveStroke = liveStroke
        self.sheen = sheen
        self.showsGloss = showsGloss
    }

    public var body: some View {
        let layout = record.layout
        let size = layout.size(forWidth: width)
        let template = TemplateCatalog.resolve(id: record.templateID, format: record.format)
        let resolvedPaper = template.resolvedPaper(stockPaper: paper)
        let layers = PrintLayerCache.shared.layers(for: record, paper: paper, width: width)

        ZStack(alignment: .topLeading) {
            // 1. 底层
            if let base = layers.base {
                Image(decorative: base, scale: layers.scale)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            }

            // 2. 图像窗口
            ForEach(Array(layout.windows.enumerated()), id: \.offset) { item in
                let rect = layout.scaled(item.element, toWidth: width)
                ZStack {
                    DevelopingWindow(
                        image: item.offset < images.count ? images[item.offset] : nil,
                        visual: item.offset < visuals.count ? visuals[item.offset] : .developed,
                        offset: item.offset < record.frameOffsets.count ? record.frameOffsets[item.offset] : .zero,
                        size: rect.size
                    )
                    if showsGloss {
                        Gloss(sheen: sheen)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .clipShape(WindowClip(shape: PhotoComposer.windowPath(layout: layout, template: template, index: item.offset, width: width), origin: rect.origin))
                .offset(x: rect.minX, y: rect.minY)
            }

            // 3. 上层
            if let overlay = layers.overlay {
                Image(decorative: overlay, scale: layers.scale)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            }

            // 4. 正在写的一笔
            if let liveStroke {
                LiveInk(stroke: liveStroke, paperWidth: width, ink: resolvedPaper.inkRGB)
                    .frame(width: size.width, height: size.height)
            }

            // 卷曲明暗（只落在相纸上）
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0), Color.black.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
            .blendMode(.overlay)
            .mask {
                if let base = layers.base {
                    Image(decorative: base, scale: layers.scale)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                } else {
                    Color.clear
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .overlay(
            PaperEdge(
                cornerRadius: layout.cornerRadius * width / layout.paperSize.width,
                width: width,
                dark: resolvedPaper.isDark,
                visible: !template.hasCustomOutline
            )
        )
    }
}

/// 纸边倒角的一圈高光（毛边、邮票齿孔这种不规则外缘不画）。
private struct PaperEdge: View {
    let cornerRadius: CGFloat
    let width: CGFloat
    let dark: Bool
    let visible: Bool

    var body: some View {
        if visible {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(dark ? 0.18 : 0.85), Color.white.opacity(0.08), Color.black.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.6, width * 0.004)
                )
                .allowsHitTesting(false)
        }
    }
}

/// 窗口形状（模板给的路径是相纸坐标，这里平移到窗口自己的坐标）。
struct WindowClip: Shape {
    let shape: CGPath
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var move = CGAffineTransform(translationX: -origin.x, y: -origin.y)
        guard let local = shape.copy(using: &move) else { return Path(rect) }
        return Path(local)
    }
}

/// 正在写的一笔（与成片同一套笔触画法）。
private struct LiveInk: View {
    let stroke: InkStroke
    let paperWidth: CGFloat
    let ink: RGB

    var body: some View {
        Canvas { context, _ in
            context.withCGContext { cg in
                PhotoComposer.drawStrokes([stroke], in: cg, paperWidth: paperWidth, defaultInk: ink)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 相纸底层 / 上层的缓存：只在装饰（模板、题字、贴纸、笔画……）或尺寸变化时重新渲染，
/// 显影动画每一帧都复用同一对图。
public final class PrintLayerCache: @unchecked Sendable {
    public static let shared = PrintLayerCache()

    public struct Layers {
        public let base: CGImage?
        public let overlay: CGImage?
        /// 像素 / 点。
        public let scale: CGFloat
    }

    private final class Box {
        let layers: Layers
        init(_ layers: Layers) { self.layers = layers }
    }

    private let cache: NSCache<NSNumber, Box> = {
        let cache = NSCache<NSNumber, Box>()
        cache.countLimit = 160
        return cache
    }()

    /// 屏幕渲染用的像素密度。
    public var renderScale: CGFloat = 2

    public func layers(for record: PhotoRecord, paper: PaperStyle, width: CGFloat) -> Layers {
        let scale = renderScale
        let pixels = max(64, Int((width * scale).rounded()))
        var hasher = Hasher()
        hasher.combine(record.id)
        hasher.combine(record.format)
        hasher.combine(record.templateID)
        hasher.combine(record.caption)
        hasher.combine(record.showsDate)
        hasher.combine(record.displayDate)
        hasher.combine(record.captionFont)
        hasher.combine(record.tags)
        hasher.combine(record.location)
        hasher.combine(record.showsTags)
        hasher.combine(record.showsLocation)
        hasher.combine(record.showsTagStickers)
        hasher.combine(record.stickers)
        hasher.combine(record.texts)
        hasher.combine(record.strokes)
        hasher.combine(record.seed)
        hasher.combine(paper)
        hasher.combine(pixels)
        let key = NSNumber(value: hasher.finalize())
        if let hit = cache.object(forKey: key) {
            return hit.layers
        }
        let spec = PrintSpec(record: record, stockPaper: paper, images: [], widthPixels: pixels)
        let layers = Layers(
            base: PhotoComposer.renderBase(spec),
            overlay: PhotoComposer.renderOverlay(spec),
            scale: CGFloat(pixels) / max(width, 1)
        )
        cache.setObject(Box(layers), forKey: key)
        return layers
    }

    /// 装饰台保存后可以清掉旧图（不清也会因为 key 变化自然失效）。
    public func removeAll() {
        cache.removeAllObjects()
    }
}

/// 显影中的图像：乳灰底 → 蓝色先出来 → 对比度和饱和度慢慢上来 → 最后暖色。
struct DevelopingWindow: View {
    let image: CGImage?
    let visual: DevelopmentVisual
    let offset: FrameOffset
    let size: CGSize

    var body: some View {
        ZStack {
            Color(white: 0.12)
            Color(red: 0.78, green: 0.79, blue: 0.74)
                .opacity(1 - visual.imageOpacity)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .offset(x: offset.dx * size.width, y: offset.dy * size.height)
                    .saturation(visual.saturation)
                    .contrast(visual.contrast)
                    .brightness(visual.brightness)
                    .colorMultiply(Color(red: visual.red, green: visual.green, blue: visual.blue))
                    .blur(radius: visual.blurFraction * size.width, opaque: true)
                    .opacity(visual.imageOpacity)
            }
            Color(red: 0.62, green: 0.74, blue: 0.74)
                .opacity(visual.hazeOpacity)
                .blendMode(.screen)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// 光面涂层：一道斜向的柔光和一块高光，位置随 `sheen` 移动。
struct Gloss: View {
    let sheen: CGPoint

    var body: some View {
        let s = min(max(Double(sheen.x) * 0.6 + 0.2, 0.12), 0.88)
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0), location: s - 0.12),
                    .init(color: Color.white.opacity(0.15), location: s),
                    .init(color: Color.white.opacity(0), location: s + 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0)],
                center: UnitPoint(x: sheen.x, y: sheen.y),
                startRadius: 0,
                endRadius: 140
            )
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

public extension Color {
    /// 从 NocchiKit 的 RGB 构造 sRGB 颜色。
    init(nocchi rgb: RGB, opacity: Double = 1) {
        let c = ColorMath.clamp01(rgb)
        self.init(.sRGB, red: Double(c.x), green: Double(c.y), blue: Double(c.z), opacity: opacity)
    }
}
