import AppKit
import NocchiKit
import SwiftUI

// MARK: - 数据

/// 相册数据（所有照片记录，新的在前）。
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var records: [PhotoRecord] = []

    private init() {}

    func reload() {
        let library = Services.library
        Task {
            let all = await Task.detached(priority: .utility) { library.loadAll() }.value
            self.records = all.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func upsert(_ record: PhotoRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
    }
}

/// 缩略图缓存（装饰过的照片 `editedAt` 会变，缓存键带上它）。
@MainActor
final class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    private func key(_ url: URL, version: Date?, maxPixel: Int) -> NSString {
        "\(url.path)#\(version?.timeIntervalSince1970 ?? 0)#\(maxPixel)" as NSString
    }

    func image(for url: URL, version: Date? = nil, maxPixel: Int = 520) -> NSImage? {
        cache.object(forKey: key(url, version: version, maxPixel: maxPixel))
    }

    func load(_ url: URL, version: Date? = nil, maxPixel: Int = 520) async -> NSImage? {
        let cacheKey = key(url, version: version, maxPixel: maxPixel)
        if let cached = cache.object(forKey: cacheKey) { return cached }
        let cgImage = await Task.detached(priority: .utility) { ImageIOKit.load(url, maxPixel: maxPixel) }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

/// 程序化绘制的旧物 / 胶带（`StickerArt`），按种类、宽度、seed 缓存。
@MainActor
final class StickerImageCache {
    static let shared = StickerImageCache()
    private var cache: [String: NSImage] = [:]

    func image(_ id: String, width: CGFloat, seed: UInt64 = 1) -> NSImage? {
        let cacheKey = "\(id)#\(Int(width))#\(seed)"
        if let hit = cache[cacheKey] { return hit }
        guard let kind = StickerCatalog.kind(id: id),
              let cgImage = StickerArt.image(kind, pixelWidth: Int(width * 2), tint: nil, text: nil, seed: seed),
              cgImage.width > 0 else { return nil }
        let size = NSSize(width: width, height: width * CGFloat(cgImage.height) / CGFloat(cgImage.width))
        let image = NSImage(cgImage: cgImage, size: size)
        cache[cacheKey] = image
        return image
    }
}

/// `Shared/Art.xcassets` 里有没有这张图（Blender 渲染图缺失时要有退路）。
@MainActor
enum BundledImage {
    private static var known: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let cached = known[name] { return cached }
        let found = NSImage(named: name) != nil
        known[name] = found
        return found
    }
}

// MARK: - 四种看法

enum AlbumMode: String, CaseIterable, Identifiable {
    case cork
    case cardBox
    case film
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cork: "软木板"
        case .cardBox: "卡片盒"
        case .film: "胶卷"
        case .calendar: "日历"
        }
    }

    /// Blender 渲染的小图标。
    var iconName: String {
        switch self {
        case .cork: "ModeIconCork"
        case .cardBox: "ModeIconCardBox"
        case .film: "ModeIconFilm"
        case .calendar: "ModeIconCalendar"
        }
    }

    /// 缺图时的退路。
    var symbol: String {
        switch self {
        case .cork: "pin.fill"
        case .cardBox: "archivebox.fill"
        case .film: "film.fill"
        case .calendar: "calendar"
        }
    }

    var key: KeyEquivalent {
        switch self {
        case .cork: "1"
        case .cardBox: "2"
        case .film: "3"
        case .calendar: "4"
        }
    }
}

/// 相册窗口的路由：当前看法（记住上次的选择）与「聚焦搜索框」请求（菜单 ⌘F）。
@MainActor
final class AlbumRouter: ObservableObject {
    static let shared = AlbumRouter()
    private static let modeKey = "album.view"

    @Published var mode: AlbumMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    @Published private(set) var searchRequest = 0

    private init() {
        mode = AlbumMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .cardBox
    }

    func show(_ newMode: AlbumMode) {
        WindowManager.shared.showAlbum()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            mode = newMode
        }
    }

    func focusSearch() {
        WindowManager.shared.showAlbum()
        searchRequest += 1
    }
}

// MARK: - 照片操作

@MainActor
enum AlbumActions {
    static func printURL(_ record: PhotoRecord) -> URL? {
        record.printFile.map { Services.library.printURL($0) }
    }

    /// 相册里显示用的图：成片，没有成片时用第一张底片。
    static func imageURL(_ record: PhotoRecord) -> URL? {
        printURL(record) ?? record.negatives.first.map { Services.library.negativeURL($0) }
    }

    /// 双击照片。
    static func open(_ record: PhotoRecord) {
        preview(record)
    }

    static func putOnDesk(_ record: PhotoRecord) {
        DesktopBoard.shared.put(record)
    }

    static func reveal(_ record: PhotoRecord) {
        guard let url = printURL(record) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func preview(_ record: PhotoRecord) {
        guard let url = printURL(record) else { return }
        NSWorkspace.shared.open(url)
    }

    static func trash(_ record: PhotoRecord) {
        let alert = NSAlert()
        alert.messageText = "把这张照片移到废纸篓？"
        alert.informativeText = "成片会移到废纸篓（可以恢复）；记录和底片会被删除。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let controller = DesktopBoard.shared.controllers[record.id] {
            controller.close()
        }
        if let url = printURL(record) {
            NSWorkspace.shared.recycle([url], completionHandler: nil)
        }
        Services.library.removeRecord(record, deletePrint: false)
        LibraryStore.shared.remove(id: record.id)
    }
}

/// 照片的右键菜单（软木板、卡片盒、胶卷、日历共用）。
struct AlbumContextMenu: View {
    let record: PhotoRecord

    var body: some View {
        Button("放回桌面") { AlbumActions.putOnDesk(record) }
        if record.printFile != nil {
            Button("在 Finder 中显示") { AlbumActions.reveal(record) }
            Button("用「预览」打开") { AlbumActions.preview(record) }
        }
        Divider()
        Button("移到废纸篓", role: .destructive) { AlbumActions.trash(record) }
    }
}

/// 一张照片的缩略图（成片优先），带缓存。
struct AlbumThumbnail: View {
    let record: PhotoRecord
    var maxPixel: Int = 520
    @State private var image: NSImage?

    init(record: PhotoRecord, maxPixel: Int = 520) {
        self.record = record
        self.maxPixel = maxPixel
    }

    var body: some View {
        let url = AlbumActions.imageURL(record)
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Rectangle()
                    .fill(Palette.ivoryLight)
            }
        }
        .task(id: "\(url?.path ?? "")#\(record.editedAt?.timeIntervalSince1970 ?? 0)") {
            guard let url else { return }
            if let cached = ThumbnailCache.shared.image(for: url, version: record.editedAt, maxPixel: maxPixel) {
                image = cached
                return
            }
            image = await ThumbnailCache.shared.load(url, version: record.editedAt, maxPixel: maxPixel)
        }
    }
}

// MARK: - 小纸条

/// 打字机小纸条（「3 张」「没有找到『咖啡』」）。
struct TypedSlip: View {
    let text: String
    var size: CGFloat = 12
    var tilt: Double = 1.5

    var body: some View {
        Text(text)
            .font(RetroFont.typewriter(size))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, size * 0.8)
            .padding(.vertical, size * 0.38)
            .background(
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFBF8F1), Color(hex: 0xF1EBDD)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Rectangle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.22), radius: 0.8, x: 0.4, y: 0.8)
            .shadow(color: .black.opacity(0.14), radius: 5, x: 2, y: 4)
            .rotationEffect(.degrees(tilt))
            .fixedSize()
    }
}

/// 搜索没有结果。
struct NoResultsSlip: View {
    let query: String

    var body: some View {
        VStack(spacing: 6) {
            TypedSlip(text: "没有找到『\(query.trimmingCharacters(in: .whitespacesAndNewlines))』", size: 14, tilt: -1.2)
            Text("试试题字、#标签、地点、胶卷名，或者「2026/11」这样的日期")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - 窗口拖动

/// 透明标题栏下面的顶栏：空白处可以拖动窗口，双击按系统设置缩放 / 最小化。
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
                case "Minimize": window.performMiniaturize(nil)
                case "None": break
                default: window.performZoom(nil)
                }
            } else {
                window.performDrag(with: event)
            }
        }
    }
}

/// 一个用闭包响应的菜单项。
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}
