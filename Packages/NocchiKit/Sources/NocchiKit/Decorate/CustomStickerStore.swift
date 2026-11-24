import CoreGraphics
import Foundation

/// 用户自己导入的一枚贴纸（「我的贴纸」）。
public struct CustomSticker: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// 照片库 `stickers/` 目录里的 PNG。
    public var fileName: String
    /// 宽 / 高。
    public var aspect: Double
    /// 加一圈白色模切边（像真的贴纸）。
    public var dieCut: Bool
    /// 删掉了：不再出现在贴纸库里，但已经贴在照片上的照样画得出来。
    public var hidden: Bool
    public var createdAt: Date

    /// 写进照片记录的 `StickerPlacement.kindID`：`custom.<UUID>`。
    public var kindID: String { CustomStickerStore.prefix + id.uuidString }

    /// 当作一种贴纸来用（装饰台的贴纸库、缩略图）。
    public var kind: StickerKind {
        StickerKind(id: kindID, name: name, category: .badge, aspect: aspect, defaultSize: aspect >= 1.2 ? 0.32 : 0.24)
    }
}

/// 自定义贴纸的图（注入给 `StickerArt`，NocchiKit 不直接依赖 App 的目录）。
public struct CustomStickerArt: @unchecked Sendable {
    public let image: CGImage
    public let aspect: Double
    public let dieCut: Bool

    public init(image: CGImage, aspect: Double, dieCut: Bool) {
        self.image = image
        self.aspect = aspect
        self.dieCut = dieCut
    }
}

/// 「我的贴纸」：导入的图片（PNG / JPG / HEIC……）裁掉透明边、存成 PNG，清单写在 `stickers.json`。线程安全。
public final class CustomStickerStore: @unchecked Sendable {
    public static let prefix = "custom."

    public enum ImportError: Error, Equatable {
        case unreadable
    }

    public let directory: URL
    private let lock = NSLock()
    private var entries: [CustomSticker] = []
    private var cache: [UUID: CGImage] = [:]
    private var manifestURL: URL { directory.appendingPathComponent("stickers.json") }

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // 清单用 ISO 8601 写日期（`saveLocked`），读的时候要用同样的格式。
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? decoder.decode([CustomSticker].self, from: data) {
            entries = decoded
        }
    }

    /// 贴纸库里显示的（没删的），按用户排的顺序。
    public var stickers: [CustomSticker] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { !$0.hidden }
    }

    public func sticker(id: UUID) -> CustomSticker? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first { $0.id == id }
    }

    public static func id(fromKindID kindID: String) -> UUID? {
        guard kindID.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(kindID.dropFirst(prefix.count)))
    }

    /// 画贴纸用的图（删掉了的也能取到，照片上已经贴的不会消失）。
    public func art(forKindID kindID: String) -> CustomStickerArt? {
        guard let id = Self.id(fromKindID: kindID) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries.first(where: { $0.id == id }) else { return nil }
        if let cached = cache[id] {
            return CustomStickerArt(image: cached, aspect: entry.aspect, dieCut: entry.dieCut)
        }
        guard let image = ImageIOKit.load(directory.appendingPathComponent(entry.fileName)) else { return nil }
        cache[id] = image
        return CustomStickerArt(image: image, aspect: entry.aspect, dieCut: entry.dieCut)
    }

    // MARK: - 导入与管理

    /// 导入一张图片：最长边 1600、裁掉透明边、存成 PNG。
    @discardableResult
    public func importImage(at url: URL, name: String? = nil) throws -> CustomSticker {
        guard let image = ImageIOKit.load(url, maxPixel: 1600) else { throw ImportError.unreadable }
        return try add(image, name: name ?? url.deletingPathExtension().lastPathComponent)
    }

    @discardableResult
    public func add(_ image: CGImage, name: String) throws -> CustomSticker {
        let trimmed = Self.trimmed(image) ?? image
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        try ImageIOKit.writePNG(trimmed, to: directory.appendingPathComponent(fileName))
        let entry = CustomSticker(
            id: id,
            name: name.isEmpty ? String(localized: "我的贴纸") : name,
            fileName: fileName,
            aspect: Double(trimmed.width) / Double(max(trimmed.height, 1)),
            dieCut: true,
            hidden: false,
            createdAt: Date()
        )
        lock.lock()
        entries.append(entry)
        cache[id] = trimmed
        saveLocked()
        lock.unlock()
        return entry
    }

    public func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.name = trimmed }
    }

    public func setDieCut(_ id: UUID, _ on: Bool) {
        update(id) { $0.dieCut = on }
    }

    /// 删掉：从贴纸库里拿掉（文件留着，已经贴在照片上的照样画得出来）。
    public func remove(_ id: UUID) {
        update(id) { $0.hidden = true }
    }

    /// 在贴纸库里往前（-1）或往后（+1）挪。
    public func move(_ id: UUID, by offset: Int) {
        lock.lock()
        defer { lock.unlock() }
        let visible = entries.indices.filter { !entries[$0].hidden }
        guard let position = visible.firstIndex(where: { entries[$0].id == id }) else { return }
        let target = position + offset
        guard target >= 0, target < visible.count else { return }
        entries.swapAt(visible[position], visible[target])
        saveLocked()
    }

    private func update(_ id: UUID, _ change: (inout CustomSticker) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index])
        saveLocked()
    }

    private func saveLocked() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    // MARK: - 裁透明边

    /// 裁到不透明内容的外框（留 2 像素）；整张都不透明或全透明时返回 nil（不裁）。
    static func trimmed(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 2, height > 2,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width where bytes[row + x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        if minX == 0, minY == 0, maxX == width - 1, maxY == height - 1 { return nil }
        let pad = 2
        // CGContext 的数据是从上往下存的（第 0 行在最上面），和 CGImage.cropping 的坐标一致。
        let rect = CGRect(
            x: max(0, minX - pad),
            y: max(0, minY - pad),
            width: min(width, maxX + pad + 1) - max(0, minX - pad),
            height: min(height, maxY + pad + 1) - max(0, minY - pad)
        )
        return image.cropping(to: rect)
    }
}
