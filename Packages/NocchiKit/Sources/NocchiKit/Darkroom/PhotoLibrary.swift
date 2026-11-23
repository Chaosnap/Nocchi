import CoreGraphics
import Foundation

/// 照片库：只存在本机，不上传。
///
/// - `root/records/<id>.json`：每张照片一份记录（单文件写入，互不影响）
/// - `root/negatives/<id>-<n>.jpg`：冲印好的底片（不含白边）
/// - `root/luts/*.cube`：用户导入的 LUT
/// - `printsRoot/<yyyy-MM>/Nocchi_<yyyyMMdd_HHmmss>.jpg`：带白边的成片（给用户看的文件）
public final class PhotoLibrary: @unchecked Sendable {
    public let root: URL
    public let printsRoot: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public var recordsDirectory: URL { root.appendingPathComponent("records", isDirectory: true) }
    public var negativesDirectory: URL { root.appendingPathComponent("negatives", isDirectory: true) }
    public var lutsDirectory: URL { root.appendingPathComponent("luts", isDirectory: true) }

    public init(root: URL, printsRoot: URL) throws {
        self.root = root
        self.printsRoot = printsRoot
        for dir in [root, recordsDirectory, negativesDirectory, lutsDirectory, printsRoot] {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Records

    public func save(_ record: PhotoRecord) throws {
        let data = try encoder.encode(record)
        try data.write(to: recordURL(record.id), options: .atomic)
    }

    public func record(id: UUID) -> PhotoRecord? {
        guard let data = try? Data(contentsOf: recordURL(id)) else { return nil }
        return try? decoder.decode(PhotoRecord.self, from: data)
    }

    /// 全部记录，新的在前。
    public func loadAll() -> [PhotoRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: recordsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? decoder.decode(PhotoRecord.self, from: $0) } }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 删除记录和底片；成片文件交给调用方处理（Mac 移到废纸篓）。
    public func removeRecord(_ record: PhotoRecord, deletePrint: Bool) {
        try? fileManager.removeItem(at: recordURL(record.id))
        for name in record.negatives {
            try? fileManager.removeItem(at: negativeURL(name))
        }
        if deletePrint, let print = record.printFile {
            try? fileManager.removeItem(at: printURL(print))
        }
    }

    private func recordURL(_ id: UUID) -> URL {
        recordsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: Negatives

    @discardableResult
    public func writeNegative(_ image: CGImage, recordID: UUID, index: Int) throws -> String {
        let name = "\(recordID.uuidString)-\(index).jpg"
        try ImageIOKit.writeJPEG(image, to: negativeURL(name), quality: 0.93)
        return name
    }

    public func negativeURL(_ name: String) -> URL {
        negativesDirectory.appendingPathComponent(name)
    }

    public func loadNegatives(of record: PhotoRecord) -> [CGImage] {
        record.negatives.compactMap { ImageIOKit.load(negativeURL($0)) }
    }

    // MARK: Prints

    /// 写入带白边的成片，返回相对路径。已有成片时覆盖同一个文件。
    @discardableResult
    public func writePrint(_ image: CGImage, for record: PhotoRecord) throws -> String {
        let relative = record.printFile ?? PhotoLibrary.printRelativePath(for: record)
        let url = printURL(relative)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ImageIOKit.writeJPEG(image, to: url, quality: 0.94)
        return relative
    }

    public func printURL(_ relative: String) -> URL {
        printsRoot.appendingPathComponent(relative)
    }

    public static func printRelativePath(for record: PhotoRecord) -> String {
        let month = monthKeyFormatter.string(from: record.createdAt)
        let stamp = fileStampFormatter.string(from: record.createdAt)
        let suffix = record.id.uuidString.prefix(4).lowercased()
        return "\(month)/Nocchi_\(stamp)_\(suffix).jpg"
    }

    // MARK: LUTs

    /// 导入用户的 `.cube`（先校验），返回保存后的文件名。
    public func importLUT(from url: URL) throws -> (fileName: String, lut: CubeLUT) {
        let lut = try CubeLUT(contentsOf: url)
        let base = url.deletingPathExtension().lastPathComponent
        let safe = base.replacingOccurrences(of: "/", with: "-")
        let name = "\(safe)-\(UUID().uuidString.prefix(6).lowercased()).cube"
        let dest = lutsDirectory.appendingPathComponent(name)
        try fileManager.copyItem(at: url, to: dest)
        return (name, lut)
    }

    // MARK: Grouping

    static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    public struct MonthGroup: Identifiable, Sendable {
        public var id: String { key }
        /// 「2026-11」
        public var key: String
        /// 「2026 年 11 月」
        public var title: String
        public var records: [PhotoRecord]
    }

    /// 按月份分组（软木板相册），新的月份在前。
    public static func groupedByMonth(_ records: [PhotoRecord], calendar: Calendar = .current) -> [MonthGroup] {
        var groups: [String: [PhotoRecord]] = [:]
        for record in records {
            groups[monthKeyFormatter.string(from: record.createdAt), default: []].append(record)
        }
        return groups.keys.sorted(by: >).map { key in
            let parts = key.split(separator: "-")
            let title = parts.count == 2 ? "\(parts[0]) 年 \(Int(parts[1]) ?? 0) 月" : key
            let items = (groups[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            return MonthGroup(key: key, title: title, records: items)
        }
    }
}
