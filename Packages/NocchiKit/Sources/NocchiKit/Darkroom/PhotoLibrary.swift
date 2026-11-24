import CoreGraphics
import Foundation

/// 照片库：只存在本机，不上传。
///
/// - `root/records/<id>.json`：每张照片一份记录（单文件写入，互不影响）
/// - `root/negatives/<id>-<n>.jpg`：冲印好的底片（不含白边）
/// - `root/luts/*.cube`：用户导入的 LUT
/// - `printsRoot/<yyyy-MM>/Nocchi_<yyyyMMdd_HHmmss>.jpg`：带白边的成片（给用户看的文件）
///
/// 成片的位置可以换（设置 → 通用 → 存储，`relocatePrints(to:)`）：记录里存的是相对路径，搬过去照样找得到。
public final class PhotoLibrary: @unchecked Sendable {
    public let root: URL
    /// 成片放在哪里（线程安全；换位置见 `relocatePrints(to:)`）。
    public var printsRoot: URL {
        printsLock.lock()
        defer { printsLock.unlock() }
        return currentPrintsRoot
    }
    private var currentPrintsRoot: URL
    private let printsLock = NSLock()
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
        self.currentPrintsRoot = printsRoot
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

    /// 换成片位置时出的错。
    public enum RelocationError: Error, Equatable {
        /// 新位置在现在的成片文件夹里面，或者反过来。
        case nested
        /// 新位置是一个文件，不是文件夹。
        case notAFolder
    }

    /// 换成片位置的结果。
    public struct RelocationResult: Equatable, Sendable {
        /// 搬过去的文件数。
        public let moved: Int
        /// 新位置已经有同名文件、没有覆盖、留在原处的文件（相对路径）。
        public let skipped: [String]
    }

    /// 原来成片文件夹里有几个文件（月份文件夹里的成片等，不算隐藏文件）。
    public func printFileCount() -> Int {
        files(under: printsRoot).count
    }

    /// 把成片换到 `newRoot`：先改用新位置（之后冲印的成片直接写到那里），再把原来文件夹里的文件
    /// 按原来的相对路径一个个搬过去；记录里存的是相对路径，搬完照样找得到。
    ///
    /// 新位置已经有同名文件时不覆盖，原文件留在原处（列在结果里）。搬到一半出错：已经搬过去的搬回来、
    /// 改回原来的位置，再把错抛出去。搬空的月份文件夹顺手删掉（原来的成片文件夹本身留着）。
    @discardableResult
    public func relocatePrints(to newRoot: URL) throws -> RelocationResult {
        let old = printsRoot.standardizedFileURL
        let new = newRoot.standardizedFileURL
        let oldPath = Self.folderPath(old)
        let newPath = Self.folderPath(new)
        if oldPath == newPath {
            return RelocationResult(moved: 0, skipped: [])
        }
        if newPath.hasPrefix(oldPath) || oldPath.hasPrefix(newPath) {
            throw RelocationError.nested
        }
        var isFolder: ObjCBool = false
        if fileManager.fileExists(atPath: new.path, isDirectory: &isFolder), !isFolder.boolValue {
            throw RelocationError.notAFolder
        }
        try fileManager.createDirectory(at: new, withIntermediateDirectories: true)
        setPrintsRoot(new)

        var moved: [(from: URL, to: URL)] = []
        var skipped: [String] = []
        do {
            for relative in files(under: old) {
                let source = old.appendingPathComponent(relative)
                let destination = new.appendingPathComponent(relative)
                if fileManager.fileExists(atPath: destination.path) {
                    skipped.append(relative)
                    continue
                }
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: source, to: destination)
                moved.append((source, destination))
            }
        } catch {
            for pair in moved.reversed() {
                try? fileManager.createDirectory(at: pair.from.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.moveItem(at: pair.to, to: pair.from)
            }
            setPrintsRoot(old)
            throw error
        }
        removeEmptyFolders(in: old)
        return RelocationResult(moved: moved.count, skipped: skipped)
    }

    private func setPrintsRoot(_ url: URL) {
        printsLock.lock()
        currentPrintsRoot = url
        printsLock.unlock()
    }

    /// 文件夹下所有（不隐藏的）文件的相对路径。
    private func files(under folder: URL) -> [String] {
        let subpaths = (try? fileManager.subpathsOfDirectory(atPath: folder.path)) ?? []
        return subpaths.filter { relative in
            guard !relative.split(separator: "/").contains(where: { $0.hasPrefix(".") }) else { return false }
            var isFolder: ObjCBool = false
            return fileManager.fileExists(atPath: folder.appendingPathComponent(relative).path, isDirectory: &isFolder) && !isFolder.boolValue
        }
        .sorted()
    }

    /// 删掉搬空了的子文件夹（只剩 `.DS_Store` 也算空），从最深的开始；`folder` 本身留着。
    private func removeEmptyFolders(in folder: URL) {
        let subpaths = (try? fileManager.subpathsOfDirectory(atPath: folder.path)) ?? []
        for relative in subpaths.sorted(by: { $0.count > $1.count }) {
            let url = folder.appendingPathComponent(relative)
            var isFolder: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue else { continue }
            let contents = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
            if contents.allSatisfy({ $0 == ".DS_Store" }) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// 比较用的文件夹路径：解开符号链接（/var → /private/var），以 `/` 结尾。
    private static func folderPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasSuffix("/") ? path : path + "/"
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
