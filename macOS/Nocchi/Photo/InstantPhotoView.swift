import NocchiKit
import SwiftUI

/// 桌面上的一张相片（含出片遮罩、倾斜、分层阴影）。
struct InstantPhotoView: View {
    @ObservedObject var model: PhotoViewModel

    var body: some View {
        let pad = PhotoViewModel.padding
        let size = model.paperSize
        let window = model.windowSize
        PaperView(model: model)
            .frame(width: size.width, height: size.height)
            .scaleEffect(model.lifted ? 1.035 : 1)
            .rotationEffect(.degrees(model.tilt))
            // 两层阴影：贴着桌面的接触阴影 + 柔和的环境阴影；拿起来时更远更散。
            .shadow(color: .black.opacity(model.lifted ? 0.10 : 0.22), radius: model.lifted ? 3 : 1.2, x: 0, y: model.lifted ? 3 : 1)
            .shadow(color: .black.opacity(model.lifted ? 0.26 : 0.16), radius: model.lifted ? 18 : 10, x: 0, y: model.lifted ? 13 : 6)
            .offset(y: -size.height * (1 - model.ejectProgress))
            .frame(width: window.width, height: window.height)
            .mask(alignment: .bottom) {
                Rectangle()
                    .frame(width: window.width, height: model.masking ? window.height - pad : window.height)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: model.lifted)
    }
}

/// 相纸本体：纸面、图像窗口（显影动画）、题字、手写。
struct PaperView: View {
    @ObservedObject var model: PhotoViewModel

    var body: some View {
        let layout = model.layout
        let width = model.paperWidth
        let size = model.paperSize
        let corner = layout.cornerRadius * width / layout.paperSize.width
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape.fill(Color(rgb: model.paper.paperRGB))
            Image("PaperTexture")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .blendMode(.multiply)
                .opacity(model.paper.isDark ? 0.15 : 0.55)
                .allowsHitTesting(false)

            ForEach(Array(layout.windows.enumerated()), id: \.offset) { item in
                let rect = layout.scaled(item.element, toWidth: width)
                DevelopingFrame(
                    image: model.image(at: item.offset),
                    visual: model.visual(at: item.offset),
                    offset: model.frameOffset(item.offset),
                    size: rect.size,
                    darkPaper: model.paper.isDark
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
            }

            CaptionLayer(
                layout: layout,
                paperWidth: width,
                caption: model.record.caption,
                date: model.record.showsDate ? model.record.dateText : nil,
                ink: Color(rgb: model.paper.inkRGB)
            )

            InkLayer(strokes: model.record.strokes + (model.liveStroke.map { [$0] } ?? []), paperWidth: width)
                .frame(width: size.width, height: size.height)

            // 纸面的柔光：只是屏幕上的质感，不进成片。
            LinearGradient(
                colors: [Color.white.opacity(0.16), Color.white.opacity(0), Color.white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}

/// 一格图像窗口的显影：乳灰底色 → 蓝色先出来 → 对比度和饱和度慢慢上来 → 最后暖色。
struct DevelopingFrame: View {
    let image: CGImage?
    let visual: DevelopmentVisual
    let offset: FrameOffset
    let size: CGSize
    let darkPaper: Bool

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
            // 窗口边缘的压痕阴影。
            Rectangle()
                .strokeBorder(Color.black.opacity(darkPaper ? 0.35 : 0.12), lineWidth: 0.8)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// 白边上的题字和日期（与 `PhotoComposer` 用同样的字体与字号）。
struct CaptionLayer: View {
    let layout: PaperLayout
    let paperWidth: CGFloat
    let caption: String?
    let date: String?
    let ink: Color

    var body: some View {
        let area = layout.scaled(layout.captionArea, toWidth: paperWidth)
        let captionSize = PhotoComposer.captionFontSize(paperWidth: paperWidth, layout: layout)
        let dateSize = PhotoComposer.dateFontSize(paperWidth: paperWidth, layout: layout)
        VStack(spacing: 1) {
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom(PhotoComposer.captionFontName, size: captionSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            if let date {
                Text(date)
                    .font(.custom(PhotoComposer.dateFontName, size: dateSize))
                    .opacity(0.75)
            }
        }
        .foregroundStyle(ink)
        .frame(width: area.width, height: area.height)
        .offset(x: area.minX, y: area.minY)
        .allowsHitTesting(false)
    }
}

/// 手写笔画。
struct InkLayer: View {
    let strokes: [InkStroke]
    let paperWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                let color = Color(hex: stroke.color)
                let points = stroke.points
                if points.count == 1, let p = points.first {
                    let r = p.w * paperWidth / 2
                    let rect = CGRect(x: p.x * paperWidth - r, y: p.y * paperWidth - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    continue
                }
                guard points.count > 1 else { continue }
                for index in 1..<points.count {
                    let a = points[index - 1]
                    let b = points[index]
                    var path = Path()
                    path.move(to: CGPoint(x: a.x * paperWidth, y: a.y * paperWidth))
                    path.addLine(to: CGPoint(x: b.x * paperWidth, y: b.y * paperWidth))
                    let style = StrokeStyle(lineWidth: (a.w + b.w) / 2 * paperWidth, lineCap: .round, lineJoin: .round)
                    context.stroke(path, with: .color(color), style: style)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
