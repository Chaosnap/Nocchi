import AppKit
import NocchiKit
import SwiftUI

/// 装饰台中间的相纸。层次（下 → 上）：相纸层（模板、照片、题字，后台合成）→ 笔画 → 贴纸 → 正在画的笔画。
///
/// 选择工具：点贴纸选中、拖动移动，右下角手柄缩放 + 旋转，左上角 × 删除，点空白取消选中。
/// 画笔：按住拖动画一笔（照片和白边上都能画）。橡皮：点哪条笔画删哪条。
struct PaperStage: View {
    @ObservedObject var session: DecorateSession
    let width: CGFloat
    @FocusState private var focused: Bool

    var body: some View {
        let height = width * CGFloat(session.paperHeightRatio)
        ZStack(alignment: .topLeading) {
            paperLayer(height: height)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    session.selectedSticker = nil
                    session.selectedText = nil
                }
            StrokeLayer(strokes: session.record.strokes, width: width)
            ForEach(session.record.stickers) { sticker in
                StickerItem(session: session, sticker: sticker, paperWidth: width)
            }
            ForEach(session.record.texts) { text in
                TextItem(session: session, placement: text, paperWidth: width)
            }
            if let live = session.liveStroke {
                StrokeLayer(strokes: [live], width: width)
            }
            switch session.tool {
            case .ink, .eraser:
                InkInput(session: session, width: width)
            case .text:
                TextTapInput(session: session, width: width)
            case .select:
                EmptyView()
            }
        }
        .frame(width: width, height: height)
        .coordinateSpace(name: PaperStage.space)
        // 把图片直接拖到照片上：做成「我的贴纸」，贴在放下的地方。
        .dropDestination(for: URL.self) { urls, location in
            let added = StickerShelf.shared.importFiles(urls)
            for (index, sticker) in added.enumerated() {
                let offset = CGFloat(index) * 0.04
                session.addSticker(sticker.kind, at: CGPoint(x: location.x / width + offset, y: location.y / width + offset))
            }
            return !added.isEmpty
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.delete) {
            guard session.selectedSticker != nil || session.selectedText != nil else { return .ignored }
            session.deleteSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            guard session.selectedSticker != nil || session.selectedText != nil else { return .ignored }
            session.selectedSticker = nil
            session.selectedText = nil
            return .handled
        }
        .onAppear { session.refreshPaperLayer(width: width) }
        .onChange(of: width) { _, newWidth in session.refreshPaperLayer(width: newWidth) }
        .onChange(of: session.record) { _, _ in session.refreshPaperLayer(width: width) }
        .onChange(of: session.selectedSticker) { _, id in
            if id != nil { focused = true }
        }
        .onChange(of: session.selectedText) { _, id in
            if id != nil, session.tab != .text { focused = true }
        }
    }

    static let space = "paper"

    @ViewBuilder
    private func paperLayer(height: CGFloat) -> some View {
        Group {
            if let image = session.paperLayer {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                Rectangle()
                    .fill(Palette.ivoryLight)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0.6, y: 1.2)
        .shadow(color: .black.opacity(0.4), radius: 26, x: 8, y: 20)
    }
}

/// 一组笔画（相纸宽度单位 → 显示坐标），和导出用同一个画法。
struct StrokeLayer: View {
    let strokes: [InkStroke]
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            context.withCGContext { cg in
                PhotoComposer.drawStrokes(strokes, in: cg, paperWidth: width, defaultInk: RGB(0.17, 0.16, 0.15))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 画笔 / 橡皮的输入层（只有选了画笔或橡皮时才铺在最上面）。
private struct InkInput: View {
    @ObservedObject var session: DecorateSession
    let width: CGFloat

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = CGPoint(x: value.location.x / width, y: value.location.y / width)
                        switch session.tool {
                        case .ink:
                            if session.liveStroke == nil {
                                session.beginStroke(at: point)
                            } else {
                                session.continueStroke(at: point)
                            }
                        case .eraser:
                            session.erase(at: point)
                        case .select, .text:
                            break
                        }
                    }
                    .onEnded { _ in
                        session.endStroke()
                    }
            )
    }
}

/// 相纸上的一枚贴纸。选中时虚线框 + 右下角缩放 / 旋转手柄 + 左上角删除。
private struct StickerItem: View {
    @ObservedObject var session: DecorateSession
    let sticker: StickerPlacement
    let paperWidth: CGFloat
    @State private var dragOrigin: CGPoint?
    @State private var handleOrigin: HandleOrigin?

    private struct HandleOrigin {
        let size: Double
        let rotation: Double
        let vector: CGVector
    }

    init(session: DecorateSession, sticker: StickerPlacement, paperWidth: CGFloat) {
        self.session = session
        self.sticker = sticker
        self.paperWidth = paperWidth
    }

    var body: some View {
        let frame = StickerArt.frame(of: sticker, paperWidth: paperWidth)
        let selected = session.selectedSticker == sticker.id
        ZStack {
            Group {
                if let image = StickerImageCache.shared.image(for: sticker, width: frame.width) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    // 自定义贴纸的图片找不到了：留一个虚线框，删掉或换一枚。
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Palette.inkSoft.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .scaleEffect(x: sticker.flipped ? -1 : 1, y: 1)
            if selected {
                Rectangle()
                    .strokeBorder(Palette.terracotta, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .padding(-6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: max(frame.width, 4), height: max(frame.height, 4))
        .overlay(alignment: .bottomTrailing) {
            if selected {
                HandleKnob(symbol: "arrow.up.left.and.arrow.down.right")
                    .offset(x: 13, y: 13)
                    .gesture(handleGesture(center: CGPoint(x: frame.midX, y: frame.midY)))
                    .help("拖动缩放、旋转")
            }
        }
        .overlay(alignment: .topLeading) {
            if selected {
                HandleKnob(symbol: "xmark")
                    .offset(x: -13, y: -13)
                    .onTapGesture { session.deleteSelectedSticker() }
                    .help("删掉这枚贴纸")
            }
        }
        .rotationEffect(.degrees(sticker.rotation))
        .contentShape(Rectangle())
        .onTapGesture {
            session.selectedSticker = sticker.id
            session.tool = .select
        }
        .gesture(moveGesture)
        .allowsHitTesting(session.tool == .select)
        .position(x: frame.midX, y: frame.midY)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(PaperStage.space))
            .onChanged { value in
                if dragOrigin == nil {
                    session.checkpoint()
                    session.selectedSticker = sticker.id
                    dragOrigin = CGPoint(x: sticker.x, y: sticker.y)
                }
                guard let origin = dragOrigin else { return }
                let x = min(max(Double(origin.x) + Double(value.translation.width / paperWidth), -0.1), 1.1)
                // 先读出来：改 record 的闭包里不能再读 session（独占访问）。
                let maxY = session.paperHeightRatio + 0.1
                let y = min(max(Double(origin.y) + Double(value.translation.height / paperWidth), -0.1), maxY)
                session.updateSticker(sticker.id) { placement in
                    placement.x = x
                    placement.y = y
                }
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private func handleGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(PaperStage.space))
            .onChanged { value in
                let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                if handleOrigin == nil {
                    session.checkpoint()
                    let start = CGVector(dx: value.startLocation.x - center.x, dy: value.startLocation.y - center.y)
                    handleOrigin = HandleOrigin(size: sticker.size, rotation: sticker.rotation, vector: start)
                }
                guard let origin = handleOrigin else { return }
                let startLength = max(4, hypot(origin.vector.dx, origin.vector.dy))
                let length = hypot(vector.dx, vector.dy)
                let angle = atan2(vector.dy, vector.dx) - atan2(origin.vector.dy, origin.vector.dx)
                session.updateSticker(sticker.id) { placement in
                    placement.size = min(max(origin.size * Double(length / startLength), 0.04), 1.4)
                    placement.rotation = origin.rotation + Double(angle) * 180 / .pi
                }
            }
            .onEnded { _ in
                handleOrigin = nil
            }
    }
}

/// 贴纸手柄：白底陶土橙小圆钮。
private struct HandleKnob: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(Color.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Palette.terracotta))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .contentShape(Circle())
    }
}

/// 文字工具：在照片上点一下，就在那里加一个文字框。
private struct TextTapInput: View {
    @ObservedObject var session: DecorateSession
    let width: CGFloat

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        session.addText(at: CGPoint(x: value.location.x / width, y: value.location.y / width))
                    }
            )
            .onHover { inside in
                if inside { NSCursor.iBeam.push() } else { NSCursor.pop() }
            }
    }
}

/// 相纸上的一个文字框：和导出用同一个画法（`TextArt`）。选中时虚线框 + 缩放 / 旋转手柄 + 删除；双击改字。
private struct TextItem: View {
    @ObservedObject var session: DecorateSession
    let placement: TextPlacement
    let paperWidth: CGFloat
    @State private var dragOrigin: CGPoint?
    @State private var handleOrigin: (size: Double, rotation: Double, vector: CGVector)?

    init(session: DecorateSession, placement: TextPlacement, paperWidth: CGFloat) {
        self.session = session
        self.placement = placement
        self.paperWidth = paperWidth
    }

    var body: some View {
        let frame = TextArt.frame(of: placement, paperWidth: paperWidth)
        let selected = session.selectedText == placement.id
        ZStack {
            if let image = TextImageCache.shared.image(for: placement, paperWidth: paperWidth) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Palette.terracotta.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if selected {
                Rectangle()
                    .strokeBorder(Palette.cobalt, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .padding(-5)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: max(frame.width, 12), height: max(frame.height, 12))
        .overlay(alignment: .bottomTrailing) {
            if selected {
                TextKnob(symbol: "arrow.up.left.and.arrow.down.right")
                    .offset(x: 12, y: 12)
                    .gesture(handleGesture(center: CGPoint(x: frame.midX, y: frame.midY)))
                    .help("拖动缩放、旋转")
            }
        }
        .overlay(alignment: .topLeading) {
            if selected {
                TextKnob(symbol: "xmark")
                    .offset(x: -12, y: -12)
                    .onTapGesture { session.deleteSelectedText() }
                    .help("删掉这段字")
            }
        }
        .rotationEffect(.degrees(placement.rotation))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            session.selectedText = placement.id
            session.tab = .text
            session.textFocusRequest += 1
        }
        .onTapGesture {
            session.selectedText = placement.id
        }
        .gesture(moveGesture)
        .allowsHitTesting(session.tool == .select)
        .position(x: frame.midX, y: frame.midY)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(PaperStage.space))
            .onChanged { value in
                if dragOrigin == nil {
                    session.checkpoint()
                    session.selectedText = placement.id
                    dragOrigin = CGPoint(x: placement.x, y: placement.y)
                }
                guard let origin = dragOrigin else { return }
                let maxY = session.paperHeightRatio + 0.1
                let x = min(max(Double(origin.x) + Double(value.translation.width / paperWidth), -0.1), 1.1)
                let y = min(max(Double(origin.y) + Double(value.translation.height / paperWidth), -0.1), maxY)
                session.updateText(placement.id) { text in
                    text.x = x
                    text.y = y
                }
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private func handleGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(PaperStage.space))
            .onChanged { value in
                let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                if handleOrigin == nil {
                    session.checkpoint()
                    let start = CGVector(dx: value.startLocation.x - center.x, dy: value.startLocation.y - center.y)
                    handleOrigin = (placement.size, placement.rotation, start)
                }
                guard let origin = handleOrigin else { return }
                let startLength = max(4, hypot(origin.vector.dx, origin.vector.dy))
                let length = hypot(vector.dx, vector.dy)
                let angle = atan2(vector.dy, vector.dx) - atan2(origin.vector.dy, origin.vector.dx)
                let size = min(max(origin.size * Double(length / startLength), 0.02), 0.4)
                let rotation = origin.rotation + Double(angle) * 180 / .pi
                session.updateText(placement.id) { text in
                    text.size = size
                    text.rotation = rotation
                }
            }
            .onEnded { _ in
                handleOrigin = nil
            }
    }
}

/// 文字框手柄：白底钴蓝小圆钮（和贴纸的陶土橙区分开）。
private struct TextKnob: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(Color.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Palette.cobalt))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .contentShape(Circle())
    }
}

/// 文字框的渲染缓存（2 倍像素，按内容和相纸宽度）。
@MainActor
final class TextImageCache {
    static let shared = TextImageCache()
    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 160
        return cache
    }()

    func image(for placement: TextPlacement, paperWidth: CGFloat) -> NSImage? {
        let bucket = Int((paperWidth / 8).rounded()) * 8
        let key = "\(placement.hashValue)#\(bucket)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let cgImage = TextArt.image(placement, paperWidth: CGFloat(bucket) * 2) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / 2, height: CGFloat(cgImage.height) / 2))
        cache.setObject(image, forKey: key)
        return image
    }
}
