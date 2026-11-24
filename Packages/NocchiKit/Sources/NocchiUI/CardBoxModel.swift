import CoreGraphics
import Foundation
import NocchiKit
import SwiftUI

/// 读一张卡片要显示的图（通常是带白边的成片）。
public typealias CardImageLoader = @Sendable (PhotoRecord) async -> CGImage?

/// 卡片盒的状态：哪些照片还在盒子里、哪些被抽出来摊在右边、谁在最上面。
@MainActor
public final class CardBoxModel: ObservableObject {
    /// 一次最多摊开几张（更多的可以拖动翻看）。
    public nonisolated static let spreadLimit = 9

    @Published public private(set) var records: [PhotoRecord] = []
    /// 抽出来的卡片，最后一个在最上面。
    @Published public private(set) var pulled: [UUID] = []
    @Published public private(set) var activeLetter: String?
    @Published public private(set) var images: [UUID: CGImage] = [:]
    /// 摊开的这一叠是什么（「W 组 · 3 张」「最近冲印 · 9 张」「搜索『咖啡』· 2 张」）。
    @Published public private(set) var spreadCaption: String?
    /// 每个首字母下有几张。
    @Published public private(set) var letterCounts: [String: Int] = [:]

    /// 双击或点开一张卡片。
    public var onOpen: ((PhotoRecord) -> Void)?
    /// 抽出 / 放回时的反馈（例如 iPhone 的触感）。
    public var onFeedback: (() -> Void)?
    public var playsSounds = true

    private let loader: CardImageLoader
    private var loading = Set<UUID>()
    private var byID: [UUID: PhotoRecord] = [:]
    private var query = ""
    private var didAutoSpread = false
    private var choreography: Task<Void, Never>?

    public init(loader: @escaping CardImageLoader) {
        self.loader = loader
    }

    // MARK: - Data

    public func update(records: [PhotoRecord]) {
        // 装饰过（editedAt 变了）的照片要重新读图。
        for record in records {
            if let old = byID[record.id], old.editedAt != record.editedAt || old.printFile != record.printFile {
                images[record.id] = nil
            }
        }
        self.records = records
        byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        pulled.removeAll { byID[$0] == nil }
        images = images.filter { byID[$0.key] != nil }
        var counts: [String: Int] = [:]
        for record in records {
            counts[record.indexLetter, default: 0] += 1
        }
        letterCounts = counts
        if !didAutoSpread, !records.isEmpty, pulled.isEmpty, query.isEmpty {
            didAutoSpread = true
            showRecent()
        }
    }

    public func record(id: UUID) -> PhotoRecord? {
        byID[id]
    }

    /// 盒子里的顺序：A 在最前面，同一字母内新的在前。
    public var boxOrder: [PhotoRecord] {
        IndexLetter.group(records.filter { !pulled.contains($0.id) }).flatMap { $0.records }
    }

    public var pulledRecords: [PhotoRecord] {
        pulled.compactMap { byID[$0] }
    }

    public var lettersWithCards: Set<String> { Set(letterCounts.keys) }

    public func count(for letter: String) -> Int {
        letterCounts[letter] ?? 0
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
            if let image, self.byID[record.id] != nil { self.images[record.id] = image }
        }
    }

    // MARK: - Actions

    /// 抽出某个字母下的全部卡片（一张一张从盒口升起，叠在已经摊开的卡片上面）。
    public func pull(letter: String) {
        let inBox = boxOrder.filter { $0.indexLetter == letter }.map(\.id)
        let total = count(for: letter)
        guard total > 0 else { return }
        activeLetter = letter
        spreadCaption = "\(letter) 组 · \(total) 张"
        if inBox.isEmpty {
            // 已经在桌上：把这一组翻到最上面。
            let onTable = pulledRecords.filter { $0.indexLetter == letter }.map(\.id)
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                pulled.removeAll { onTable.contains($0) }
                pulled.append(contentsOf: onTable)
            }
            sound()
            return
        }
        // 新的在最上面：先抽旧的。
        arrange(pulled + inBox.reversed())
    }

    /// 抽出一张。
    public func pull(_ id: UUID) {
        guard !pulled.contains(id) else {
            bringToFront(id)
            return
        }
        pulled.append(id)
        feedback()
    }

    public func bringToFront(_ id: UUID) {
        guard let index = pulled.firstIndex(of: id), index != pulled.count - 1 else { return }
        pulled.remove(at: index)
        pulled.append(id)
        sound()
    }

    /// 最上面那张塞到最下面（往后翻一张）。
    public func cycleTop() {
        guard pulled.count > 1, let top = pulled.last else { return }
        pulled.removeLast()
        pulled.insert(top, at: 0)
        sound()
    }

    /// 最下面那张抽到最上面（往前翻一张）。
    public func cycleBottom() {
        guard pulled.count > 1, let bottom = pulled.first else { return }
        pulled.removeFirst()
        pulled.append(bottom)
        sound()
    }

    public func putBack(_ id: UUID) {
        guard pulled.contains(id) else { return }
        pulled.removeAll { $0 == id }
        feedback()
        if pulled.isEmpty {
            activeLetter = nil
            spreadCaption = nil
        }
    }

    /// 全部放回（从上往下一张一张飞回盒子）。
    public func putBackAll() {
        activeLetter = nil
        spreadCaption = nil
        arrange([])
    }

    /// 摊开最近冲印的几张（打开卡片盒时的默认样子）。
    public func showRecent(limit: Int = CardBoxModel.spreadLimit) {
        let recent = records.sorted { $0.createdAt > $1.createdAt }.prefix(limit)
        activeLetter = nil
        spreadCaption = recent.isEmpty ? nil : "最近冲印 · \(recent.count) 张"
        arrange(recent.reversed().map(\.id))
    }

    /// 搜索：摊开命中的照片（新的在最上面）；清空搜索时回到「最近冲印」。
    public func applySearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        if trimmed.isEmpty {
            showRecent()
            return
        }
        let results = PhotoSearch.filter(records, query: trimmed).sorted { $0.createdAt > $1.createdAt }
        activeLetter = nil
        spreadCaption = results.isEmpty ? nil : "搜索「\(trimmed)」· \(results.count) 张"
        arrange(results.prefix(CardBoxModel.spreadLimit * 3).reversed().map(\.id))
    }

    /// 让摊开的正好是 `ids`（下 → 上）：多余的先一张张飞回去，缺的再一张张从盒口升起。
    private func arrange(_ ids: [UUID]) {
        choreography?.cancel()
        let target = ids.filter { byID[$0] != nil }
        let keep = Set(target)
        let leaving = pulled.filter { !keep.contains($0) }
        choreography = Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, id) in leaving.reversed().enumerated() {
                if Task.isCancelled { return }
                self.pulled.removeAll { $0 == id }
                if index < 4 { self.feedback() }
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            var added = 0
            for id in target where !self.pulled.contains(id) {
                if Task.isCancelled { return }
                self.pulled.append(id)
                if added < 6 { self.feedback() }
                added += 1
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            if Task.isCancelled { return }
            let settled = target.filter { self.pulled.contains($0) }
            if settled != self.pulled {
                self.pulled = settled
            }
        }
    }

    private func sound() {
        if playsSounds { SoundPlayer.shared.play(.cardSlide) }
    }

    private func feedback() {
        sound()
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
