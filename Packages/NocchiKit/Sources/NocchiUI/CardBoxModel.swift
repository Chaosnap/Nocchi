import CoreGraphics
import Foundation
import NocchiKit
import SwiftUI

/// 读一张卡片要显示的图（通常是带白边的成片）。
public typealias CardImageLoader = @Sendable (PhotoRecord) async -> CGImage?

/// 卡片盒的状态：哪些照片还在盒子里、哪些被抽出来堆在桌上、谁在最上面。
@MainActor
public final class CardBoxModel: ObservableObject {
    @Published public private(set) var records: [PhotoRecord] = []
    /// 抽出来的卡片，最后一个在最上面。
    @Published public private(set) var pulled: [UUID] = []
    @Published public private(set) var activeLetter: String?
    @Published public private(set) var images: [UUID: CGImage] = [:]

    /// 双击或点开一张卡片。
    public var onOpen: ((PhotoRecord) -> Void)?
    /// 抽出 / 放回时的反馈（例如 iPhone 的触感）。
    public var onFeedback: (() -> Void)?
    public var playsSounds = true

    private let loader: CardImageLoader
    private var loading = Set<UUID>()

    public init(loader: @escaping CardImageLoader) {
        self.loader = loader
    }

    // MARK: - Data

    public func update(records: [PhotoRecord]) {
        self.records = records
        let ids = Set(records.map(\.id))
        pulled.removeAll { !ids.contains($0) }
        images = images.filter { ids.contains($0.key) }
    }

    /// 盒子里的顺序：A 在最前面，同一字母内新的在前。
    public var boxOrder: [PhotoRecord] {
        IndexLetter.group(records.filter { !pulled.contains($0.id) }).flatMap { $0.records }
    }

    public var pulledRecords: [PhotoRecord] {
        pulled.compactMap { id in records.first { $0.id == id } }
    }

    public var lettersWithCards: Set<String> { Set(records.map(\.indexLetter)) }

    public func count(for letter: String) -> Int {
        records.filter { $0.indexLetter == letter }.count
    }

    public func image(for record: PhotoRecord) -> CGImage? {
        images[record.id]
    }

    public func loadImage(for record: PhotoRecord) {
        guard images[record.id] == nil, !loading.contains(record.id) else { return }
        loading.insert(record.id)
        let loader = self.loader
        Task {
            let image = await loader(record)
            self.loading.remove(record.id)
            if let image { self.images[record.id] = image }
        }
    }

    // MARK: - Actions

    /// 抽出某个字母下的全部卡片（一张一张飞出来）。
    public func pull(letter: String) {
        activeLetter = letter
        let inBox = boxOrder.filter { $0.indexLetter == letter }.map(\.id)
        if inBox.isEmpty {
            // 已经在桌上：把这一组翻到最上面。
            let onTable = pulledRecords.filter { $0.indexLetter == letter }.map(\.id)
            for id in onTable.reversed() { bringToFront(id) }
            return
        }
        Task {
            for id in inBox.reversed() {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) {
                    pulled.append(id)
                }
                feedback()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    /// 抽出一张。
    public func pull(_ id: UUID) {
        guard !pulled.contains(id) else {
            bringToFront(id)
            return
        }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) {
            pulled.append(id)
        }
        feedback()
    }

    public func bringToFront(_ id: UUID) {
        guard let index = pulled.firstIndex(of: id), index != pulled.count - 1 else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
            pulled.remove(at: index)
            pulled.append(id)
        }
        if playsSounds { SoundPlayer.shared.play(.cardSlide) }
    }

    /// 最上面那张塞到最下面（像翻一叠照片）。
    public func cycleTop() {
        guard pulled.count > 1, let top = pulled.last else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            pulled.removeLast()
            pulled.insert(top, at: 0)
        }
        if playsSounds { SoundPlayer.shared.play(.cardSlide) }
    }

    public func putBack(_ id: UUID) {
        guard pulled.contains(id) else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            pulled.removeAll { $0 == id }
        }
        feedback()
        if pulled.isEmpty { activeLetter = nil }
    }

    /// 全部放回（从上往下一张一张飞回盒子）。
    public func putBackAll() {
        let ids = pulled
        guard !ids.isEmpty else { return }
        Task {
            for id in ids.reversed() {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    pulled.removeAll { $0 == id }
                }
                feedback()
                try? await Task.sleep(nanoseconds: 90_000_000)
            }
            activeLetter = nil
        }
    }

    private func feedback() {
        if playsSounds { SoundPlayer.shared.play(.cardSlide) }
        onFeedback?()
    }

    // MARK: - Default loader

    /// 默认读图：有成片读成片，没有就用底片临时合成一张带白边的小图。
    public static func defaultLoader(library: PhotoLibrary, paper: @escaping @Sendable (String) -> PaperStyle) -> CardImageLoader {
        { record in
            await Task.detached(priority: .utility) { () -> CGImage? in
                if let print = record.printFile, let image = ImageIOKit.load(library.printURL(print), maxPixel: 720) {
                    return image
                }
                let negatives = record.negatives.compactMap { ImageIOKit.load(library.negativeURL($0), maxPixel: 600) }
                guard !negatives.isEmpty else { return nil }
                let spec = PrintSpec(
                    record: record,
                    stockPaper: paper(record.stockID),
                    images: negatives,
                    widthPixels: record.format.isBooth ? 320 : 560
                )
                return PhotoComposer.render(spec)
            }.value
        }
    }
}
