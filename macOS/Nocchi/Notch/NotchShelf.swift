import AppKit
import Combine
import NocchiKit
import SwiftUI
import UniformTypeIdentifiers

/// 刘海暂存架：把桌上的相片拖到刘海上暂存，像 Dropover 的 shelf。
///
/// 暂存的相片从桌面收起（仍在相册里），可以从刘海里拖出去（成片文件）、放回桌面或在 Finder 中显示。
@MainActor
final class NotchShelf: ObservableObject {
    static let shared = NotchShelf()

    /// 暂存的相片，新的在前。
    @Published private(set) var items: [PhotoRecord] = []

    private let defaultsKey = "notch.shelf.ids"

    private init() {}

    var isEmpty: Bool { items.isEmpty }

    func load() {
        let ids = (UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []).compactMap(UUID.init(uuidString:))
        items = ids.compactMap { Services.library.record(id: $0) }
    }

    func add(_ record: PhotoRecord) {
        items.removeAll { $0.id == record.id }
        items.insert(record, at: 0)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// 清空暂存架（相片仍在相册里）。
    func clear() {
        items.removeAll()
        save()
    }

    func putBackOnDesk(_ record: PhotoRecord) {
        remove(id: record.id)
        DesktopBoard.shared.put(record)
    }

    func putAllOnDesk() {
        for record in items.reversed() {
            DesktopBoard.shared.put(record)
        }
        clear()
    }

    func revealAll() {
        let urls = items.compactMap(printURL(for:))
        if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    func printURL(for record: PhotoRecord) -> URL? {
        guard let print = record.printFile else { return nil }
        let url = Services.library.printURL(print)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.id.uuidString), forKey: defaultsKey)
    }
}

// MARK: - Views

/// 叠起来的几张缩略图 + 数量（暂存架的封面）。
struct ShelfStackPreview: View {
    @ObservedObject var shelf: NotchShelf
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            ForEach(Array(shelf.items.prefix(3).enumerated().reversed()), id: \.element.id) { item in
                ShelfThumbnail(record: item.element, width: size)
                    .rotationEffect(.degrees(Double(item.offset) * -7 + 4))
                    .offset(x: CGFloat(item.offset) * -5, y: CGFloat(item.offset) * 2)
            }
        }
        .frame(width: size * 1.35, height: size * 1.4)
    }
}

/// 暂存架里的一张缩略图（可以直接拖出去，作为成片文件）。
struct ShelfThumbnail: View {
    let record: PhotoRecord
    var width: CGFloat = 64
    @State private var image: NSImage?

    var body: some View {
        let aspect = record.printFile != nil ? record.layout.aspect : record.layout.windowAspect
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
        .frame(width: width)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        .task(id: record.id) {
            let url: URL? = record.printFile.map { Services.library.printURL($0) } ?? record.negatives.first.map { Services.library.negativeURL($0) }
            if let url {
                image = await ThumbnailCache.shared.load(url, maxPixel: 320)
            }
        }
        .onDrag {
            if let url = NotchShelf.shared.printURL(for: record), let provider = NSItemProvider(contentsOf: url) {
                return provider
            }
            return NSItemProvider()
        }
    }
}

/// 刘海展开成暂存架时的内容。
struct ShelfPanel: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var shelf: NotchShelf
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    notch.closeShelf()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                Text("刘海暂存")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer(minLength: notch.metrics.rect.width + 24)
                Menu {
                    Button("全部放回桌面") { shelf.putAllOnDesk(); notch.closeShelf() }
                    Button("在 Finder 中显示") { shelf.revealAll() }
                    Divider()
                    Button("清空暂存（仍保留在相册）") { shelf.clear(); notch.closeShelf() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .frame(height: notchHeight)

            if shelf.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 22))
                    Text("把桌上的相片拖到刘海上暂存")
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxHeight: .infinity)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    VStack(spacing: 6) {
                        ShelfStackPreview(shelf: shelf, size: 58)
                        Text("\(shelf.items.count) 张")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                    }
                    .foregroundStyle(.white)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 120)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(shelf.items) { record in
                                ShelfThumbnail(record: record, width: 70)
                                    .help("拖出去即可使用成片；点一下放回桌面")
                                    .onTapGesture { shelf.putBackOnDesk(record) }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                Text("拖出去就是成片文件 · 点一下放回桌面")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
                Spacer(minLength: 0)
            }
        }
    }
}

/// 有东西拖到刘海上方时的提示（相片：暂存；图片文件：冲印）。
struct DropTargetPanel: View {
    @ObservedObject var notch: NotchController
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(Palette.terracottaLight.opacity(0.9))
                .overlay(
                    HStack(spacing: 10) {
                        Image(systemName: notch.dropKind == .files ? "photo.badge.plus" : "tray.and.arrow.down.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(notch.dropKind == .files ? "松手，冲印成拍立得" : "松手，放进刘海暂存")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            notch.acceptDroppedFiles(providers)
        }
    }
}
