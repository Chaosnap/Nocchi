import AppKit
import NocchiKit
import SwiftUI

/// 相册数据（所有照片记录，新的在前）。
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var records: [PhotoRecord] = []

    private init() {}

    var groups: [PhotoLibrary.MonthGroup] { PhotoLibrary.groupedByMonth(records) }

    func reload() {
        let library = Services.library
        Task {
            let all = await Task.detached(priority: .utility) { library.loadAll() }.value
            self.records = all
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

/// 缩略图缓存。
@MainActor
final class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url.path as NSString)
    }

    func load(_ url: URL, maxPixel: Int = 520) async -> NSImage? {
        if let cached = image(for: url) { return cached }
        let cgImage = await Task.detached(priority: .utility) { ImageIOKit.load(url, maxPixel: maxPixel) }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: url.path as NSString)
        return image
    }
}

/// 软木板相册：按月份把照片钉在软木板上。
struct AlbumView: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        ZStack {
            CorkBackground()
            if store.records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Palette.terracotta)
                    Text("软木板还是空的")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("把鼠标移到刘海，按「屏幕快门」或「自拍」拍第一张。")
                        .font(.system(size: 13))
                        .opacity(0.75)
                }
                .foregroundStyle(Palette.charcoal)
                .padding(30)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.ivoryLight.opacity(0.92)))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 34) {
                        ForEach(store.groups) { group in
                            Text("\(group.title) · \(group.records.count) 张")
                                .font(.custom("MarkerFelt-Wide", size: 24))
                                .foregroundStyle(Palette.charcoal)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Palette.ivoryLight))
                                .rotationEffect(.degrees(-1.5))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 30)], spacing: 34) {
                                ForEach(group.records) { record in
                                    PinnedPhoto(record: record)
                                }
                            }
                        }
                    }
                    .padding(36)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear { store.reload() }
    }
}

private struct CorkBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.72, green: 0.56, blue: 0.40)
            Image("CorkTexture")
                .resizable(resizingMode: .tile)
            RadialGradient(colors: [Color.clear, Color.black.opacity(0.28)], center: .center, startRadius: 200, endRadius: 900)
        }
        .ignoresSafeArea()
    }
}

/// 钉在软木板上的一张照片。
private struct PinnedPhoto: View {
    let record: PhotoRecord
    @State private var image: NSImage?

    private var url: URL? {
        if let print = record.printFile { return Services.library.printURL(print) }
        if let first = record.negatives.first { return Services.library.negativeURL(first) }
        return nil
    }

    var body: some View {
        let tilt = PhotoRecord.randomTilt(seed: record.seed) * 0.6
        let aspect = record.printFile != nil ? record.layout.aspect : record.layout.windowAspect
        ZStack(alignment: .top) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(aspect, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.ivoryLight)
                        .aspectRatio(aspect, contentMode: .fit)
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.3), radius: 9, y: 6)

            Pushpin()
                .offset(y: -8)
        }
        .rotationEffect(.degrees(tilt))
        .task(id: url) {
            if let url { image = await ThumbnailCache.shared.load(url) }
        }
        .onTapGesture(count: 2) {
            if let print = record.printFile {
                NSWorkspace.shared.open(Services.library.printURL(print))
            }
        }
        .contextMenu {
            Button("放回桌面") { DesktopBoard.shared.put(record) }
            if let print = record.printFile {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([Services.library.printURL(print)])
                }
                Button("用「预览」打开") { NSWorkspace.shared.open(Services.library.printURL(print)) }
            }
            Divider()
            Button("移到废纸篓", role: .destructive) { trash() }
        }
        .help("\(record.stockName) · \(record.dateText)")
    }

    private func trash() {
        let alert = NSAlert()
        alert.messageText = "把这张照片移到废纸篓？"
        alert.informativeText = "成片会移到废纸篓（可以恢复）；记录和底片会被删除。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let controller = DesktopBoard.shared.controllers[record.id] {
            controller.close()
        }
        if let print = record.printFile {
            NSWorkspace.shared.recycle([Services.library.printURL(print)], completionHandler: nil)
        }
        Services.library.removeRecord(record, deletePrint: false)
        LibraryStore.shared.remove(id: record.id)
    }
}

/// 图钉。
private struct Pushpin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.terracottaLight, Palette.terracotta, Color(red: 0.45, green: 0.18, blue: 0.1)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 12))
                .frame(width: 18, height: 18)
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 5, height: 5)
                .offset(x: -3, y: -3)
        }
        .shadow(color: .black.opacity(0.4), radius: 2, x: 2, y: 3)
    }
}
