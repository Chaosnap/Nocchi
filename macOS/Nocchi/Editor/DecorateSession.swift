import AppKit
import NocchiKit
import SwiftUI

/// 装饰台的一次编辑：照片记录的工作副本、当前工具、撤销 / 重做。
///
/// 所有装饰都写在 `PhotoRecord` 里（非破坏性）；「完成」时用 `PhotoComposer.render` 重新合成成片、
/// 覆盖原文件，`editedAt = Date()`，再刷新桌面上的这张照片、相册与卡片盒。
@MainActor
final class DecorateSession: ObservableObject {
    enum Tool: Equatable {
        case select
        case ink(InkTool)
        case eraser
    }

    enum Tab: String, CaseIterable, Identifiable {
        case stickers
        case templates
        case text
        case share

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stickers: "贴纸"
            case .templates: "模板"
            case .text: "文字"
            case .share: "分享"
            }
        }

        var symbol: String {
            switch self {
            case .stickers: "seal.fill"
            case .templates: "rectangle.on.rectangle.angled"
            case .text: "textformat"
            case .share: "square.and.arrow.up"
            }
        }
    }

    struct Paint: Identifiable, Hashable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    /// 颜料：8 个珐琅色。
    nonisolated static let paints: [Paint] = [
        Paint(name: "墨黑", hex: "#2B2A28"), Paint(name: "陶土", hex: "#C4593B"),
        Paint(name: "钴蓝", hex: "#2F4C8A"), Paint(name: "石油绿", hex: "#2F5F5C"),
        Paint(name: "芥末", hex: "#D9A441"), Paint(name: "印刷红", hex: "#B23A2A"),
        Paint(name: "象牙白", hex: "#F4F1EA"), Paint(name: "金", hex: "#B8955A")
    ]

    @Published var record: PhotoRecord
    @Published var tool: Tool = .select
    @Published var paint = "#2B2A28"
    /// 笔画粗细倍数（0.5…2）。
    @Published var thickness: Double = 1
    @Published var selectedSticker: UUID?
    @Published var liveStroke: InkStroke?
    @Published var tab: Tab = .stickers
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var saving = false

    let images: [CGImage]
    let stockPaper: PaperStyle
    private let original: PhotoRecord
    private var undoStack: [PhotoRecord] = []
    private var redoStack: [PhotoRecord] = []
    var onClose: (() -> Void)?

    init(record: PhotoRecord, images: [CGImage], stockPaper: PaperStyle) {
        self.record = record
        self.original = record
        self.images = images
        self.stockPaper = stockPaper
    }

    /// 相纸的高宽比（相纸宽度单位里的高度）。
    var paperHeightRatio: Double {
        let size = record.layout.paperSize
        return size.width > 0 ? Double(size.height / size.width) : 1
    }

    var hasChanges: Bool { record != original }

    /// 当前记录在某个像素宽度下的合成参数。
    func spec(widthPixels: Int) -> PrintSpec {
        PrintSpec(record: record, stockPaper: stockPaper, images: images, widthPixels: widthPixels)
    }

    // MARK: - 撤销

    /// 改动之前调用：把当前状态压进撤销栈。
    func checkpoint() {
        undoStack.append(record)
        if undoStack.count > 80 { undoStack.removeFirst() }
        redoStack.removeAll()
        refreshUndoState()
    }

    func edit(_ change: (inout PhotoRecord) -> Void) {
        checkpoint()
        change(&record)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(record)
        record = previous
        if let selected = selectedSticker, !record.stickers.contains(where: { $0.id == selected }) {
            selectedSticker = nil
        }
        refreshUndoState()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(record)
        record = next
        refreshUndoState()
    }

    private func refreshUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - 贴纸

    func addSticker(_ kind: StickerKind) {
        let date = record.displayDate
        let placement = StickerPlacement(
            kindID: kind.id,
            x: 0.5 + Double.random(in: -0.06...0.06),
            y: paperHeightRatio * 0.42 + Double.random(in: -0.05...0.05),
            size: kind.defaultSize,
            rotation: Double.random(in: -8...8),
            tint: kind.defaultTint,
            text: StickerCatalog.initialText(for: kind, date: date)
        )
        edit { $0.stickers.append(placement) }
        selectedSticker = placement.id
        tool = .select
        SoundPlayer.shared.play(.cardSlide)
    }

    func sticker(_ id: UUID) -> StickerPlacement? {
        record.stickers.first { $0.id == id }
    }

    /// 拖动 / 缩放 / 旋转时连续调用（不记撤销；手势开始时先 `checkpoint()`）。
    func updateSticker(_ id: UUID, _ change: (inout StickerPlacement) -> Void) {
        guard let index = record.stickers.firstIndex(where: { $0.id == id }) else { return }
        change(&record.stickers[index])
    }

    /// 一次性的修改（换色、翻转）：记一步撤销。
    func editSticker(_ id: UUID, _ change: (inout StickerPlacement) -> Void) {
        checkpoint()
        updateSticker(id, change)
    }

    func deleteSelectedSticker() {
        guard let id = selectedSticker else { return }
        edit { $0.stickers.removeAll { $0.id == id } }
        selectedSticker = nil
    }

    func bringSelectedToFront() {
        guard let id = selectedSticker, let index = record.stickers.firstIndex(where: { $0.id == id }) else { return }
        edit { record in
            let sticker = record.stickers.remove(at: index)
            record.stickers.append(sticker)
        }
    }

    // MARK: - 笔画

    func beginStroke(at point: CGPoint) {
        guard case .ink(let ink) = tool else { return }
        liveStroke = InkStroke(points: [inkPoint(point)], color: paint, tool: ink)
    }

    func continueStroke(at point: CGPoint) {
        guard var stroke = liveStroke else { return }
        if let last = stroke.points.last, hypot(last.x - Double(point.x), last.y - Double(point.y)) < 0.0015 { return }
        stroke.points.append(inkPoint(point))
        liveStroke = stroke
    }

    func endStroke() {
        guard let stroke = liveStroke else { return }
        liveStroke = nil
        guard stroke.points.count > 1 else { return }
        edit { $0.strokes.append(stroke) }
    }

    /// 橡皮：删掉离这一点最近的那条笔画（相纸宽度单位）。
    func erase(at point: CGPoint) {
        var best: (index: Int, distance: Double)?
        for (index, stroke) in record.strokes.enumerated() {
            for p in stroke.points {
                let d = hypot(p.x - Double(point.x), p.y - Double(point.y))
                if d < (best?.distance ?? 0.03) {
                    best = (index, d)
                }
            }
        }
        guard let hit = best else { return }
        edit { $0.strokes.remove(at: hit.index) }
    }

    private func inkPoint(_ point: CGPoint) -> InkPoint {
        InkPoint(x: Double(point.x), y: Double(point.y), w: InkStroke.width(pressure: 0.55) * thickness)
    }

    // MARK: - 相纸层（不含贴纸与笔画，后台合成、按内容缓存）

    @Published private(set) var paperLayer: CGImage?
    private var paperLayerKey: Int?
    private var paperLayerTask: Task<Void, Never>?

    /// 相纸显示宽度变了、或模板 / 题字 / 日期 / 地点 / 标签变了时重新合成。
    func refreshPaperLayer(width: CGFloat) {
        let pixels = max(64, Int(width * 2))
        var probe = record
        probe.stickers = []
        probe.strokes = []
        probe.desk = nil
        probe.editedAt = nil
        probe.printFile = nil
        var hasher = Hasher()
        hasher.combine(probe)
        hasher.combine(pixels)
        let key = hasher.finalize()
        guard key != paperLayerKey else { return }
        paperLayerKey = key
        let paper = stockPaper
        let images = self.images
        paperLayerTask?.cancel()
        paperLayerTask = Task { [weak self] in
            let image: CGImage? = await Task.detached(priority: .userInitiated) {
                PhotoComposer.render(PrintSpec(record: probe, stockPaper: paper, images: images, widthPixels: pixels))
            }.value
            guard let self, !Task.isCancelled else { return }
            self.paperLayer = image
        }
    }

    // MARK: - 保存

    /// 合成成片、写回照片库，刷新桌面与相册。
    func save() async {
        guard !saving else { return }
        saving = true
        var record = self.record
        record.editedAt = Date()
        let finished = record
        let paper = stockPaper
        let images = self.images
        let relative: String? = await Task.detached(priority: .userInitiated) {
            let spec = PrintSpec(record: finished, stockPaper: paper, images: images, widthPixels: finished.format.printPixelWidth)
            guard let image = PhotoComposer.render(spec) else { return nil }
            return try? Services.library.writePrint(image, for: finished)
        }.value
        if let relative {
            record.printFile = relative
        }
        try? Services.library.save(record)
        LibraryStore.shared.upsert(record)
        DesktopBoard.shared.refresh(record)
        self.record = record
        saving = false
    }
}
