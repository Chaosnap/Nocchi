import CoreGraphics
import Foundation
import NocchiKit
import SwiftUI

/// 读一张卡片要显示的图（通常是带白边的成片）。
public typealias CardImageLoader = @Sendable (PhotoRecord) async -> CGImage?

/// 摊开区里一张卡片被拖到的位置（相对摊开区，0…1）与角度。
public struct CardSpot: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var rotation: Double

    public init(x: Double, y: Double, rotation: Double) {
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}

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
    /// 拖动摆放过的卡片位置（记住，下次抽出来还在那里）。
    @Published public private(set) var spots: [UUID: CardSpot] = CardBoxModel.loadSpots()

    /// 双击或点开一张卡片。
    public var onOpen: ((PhotoRecord) -> Void)?
    /// 抽出 / 放回时的反馈（例如 iPhone 的触感）。
    public var onFeedback: (() -> Void)?
    public var playsSounds = true

    private let loader: CardImageLoader
    /// 每张图读的是照片的哪个版本（装饰过、成片重印过都会变，见 `imageVersion`）。
    private var imageVersions: [UUID: String] = [:]
    /// 正在读的图（照片 → 版本）。
    private var loading: [UUID: String] = [:]
    /// 连续读不到图的次数（成片还没写完时会读不到，过一会儿再试）。
    private var failures: [UUID: Int] = [:]
    private var byID: [UUID: PhotoRecord] = [:]
    private var query = ""
    private var didAutoSpread = false
    private var choreography: Task<Void, Never>?

    public init(loader: @escaping CardImageLoader) {
        self.loader = loader
    }

    // MARK: - Data

    public func update(records: [PhotoRecord]) {
        // 装饰过、成片刚印好（版本变了）的照片要重新读图。
        var stale: [UUID] = []
        for record in records {
            if let old = byID[record.id], Self.imageVersion(old) != Self.imageVersion(record) {
                stale.append(record.id)
            }
        }
        self.records = records
        byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        pulled.removeAll { byID[$0] == nil }
        if !records.isEmpty, spots.keys.contains(where: { byID[$0] == nil }) {
            spots = spots.filter { byID[$0.key] != nil }
            saveSpots()
        }
        images = images.filter { byID[$0.key] != nil }
        imageVersions = imageVersions.filter { byID[$0.key] != nil }
        failures = failures.filter { byID[$0.key] != nil }
        // 摊在桌上的卡片马上读新图（旧图先留着，新图到了再换，不会闪成空白）；还在盒子里的等露面时再读。
        for id in stale {
            guard let record = byID[id] else { continue }
            failures[id] = nil
            if pulled.contains(id) {
                loadImage(for: record)
            } else {
                images[id] = nil
                imageVersions[id] = nil
            }
        }
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

    /// 读一张卡片的图。已经是最新版本的图就不再读；读图期间照片又变了，读完再读一次最新的；
    /// 读不到（成片还没写完）就过一会儿再试。
    public func loadImage(for record: PhotoRecord) {
        let id = record.id
        let version = Self.imageVersion(record)
        if images[id] != nil, imageVersions[id] == version { return }
        if loading[id] == version { return }
        loading[id] = version
        let loader = self.loader
        Task { [weak self] in
            let image = await loader(record)
            guard let self, self.loading[id] == version else { return }
            self.loading[id] = nil
            guard let current = self.byID[id] else { return }
            if let image {
                self.images[id] = image
                self.imageVersions[id] = version
                self.failures[id] = nil
            } else {
                self.retryLater(id)
            }
            if Self.imageVersion(current) != version {
                self.loadImage(for: current)
            }
        }
    }

    /// 读不到图时过一会儿再试：0.6、1.2、2.4、4.8、9.6 秒，最多 5 次。
    private func retryLater(_ id: UUID) {
        let attempt = (failures[id] ?? 0) + 1
        failures[id] = attempt
        guard attempt <= 5 else { return }
        let delay = UInt64(0.6 * pow(2, Double(attempt - 1)) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, let record = self.byID[id] else { return }
            if self.images[id] == nil || self.imageVersions[id] != Self.imageVersion(record) {
                self.loadImage(for: record)
            }
        }
    }

    /// 照片的图是哪个版本：装饰过（editedAt）、成片印好或重印（printFile）、底片张数变了都算新版本。
    private nonisolated static func imageVersion(_ record: PhotoRecord) -> String {
        "\(record.editedAt?.timeIntervalSinceReferenceDate ?? 0)|\(record.printFile ?? "")|\(record.negatives.count)"
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

    // MARK: - Spots

    /// 记住（或忘掉）一张卡片被拖到的位置。
    public func setSpot(_ spot: CardSpot?, for id: UUID) {
        spots[id] = spot
        saveSpots()
    }

    /// 重新叠好：忘掉所有拖动过的位置，卡片回到默认的一叠。
    public func clearSpots() {
        guard !spots.isEmpty else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            spots = [:]
        }
        saveSpots()
        sound()
    }

    private nonisolated static let spotsKey = "nocchi.cardbox.spots"

    private nonisolated static func loadSpots() -> [UUID: CardSpot] {
        guard let data = UserDefaults.standard.data(forKey: spotsKey),
              let raw = try? JSONDecoder().decode([String: CardSpot].self, from: data) else { return [:] }
        var result: [UUID: CardSpot] = [:]
        for (key, value) in raw {
            if let id = UUID(uuidString: key) {
                result[id] = value
            }
        }
        return result
    }

    private func saveSpots() {
        var raw: [String: CardSpot] = [:]
        for (id, spot) in spots {
            raw[id.uuidString] = spot
        }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: Self.spotsKey)
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
