import Foundation

/// 卡片盒的首字母索引：A–Z，外加「#」放数字、符号和没有题字的照片。
///
/// 中文题字取拼音首字母（「我可以见你吗？」→ W）。
public enum IndexLetter {
    public static let other = "#"
    public static let all: [String] = (65...90).compactMap { UnicodeScalar($0).map { String(Character($0)) } } + [other]

    public static func letter(for text: String?) -> String {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let first = trimmed.first else { return other }
        let single = String(first)
        let latin = single.applyingTransform(.toLatin, reverse: false) ?? single
        let plain = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        guard let c = plain.uppercased().first, c.isASCII, c.isLetter else { return other }
        return String(c)
    }

    /// 按字母分组，组内新的在前；只返回有照片的字母。
    public static func group(_ records: [PhotoRecord]) -> [(letter: String, records: [PhotoRecord])] {
        var buckets: [String: [PhotoRecord]] = [:]
        for record in records {
            buckets[record.indexLetter, default: []].append(record)
        }
        return all.compactMap { letter in
            guard let items = buckets[letter], !items.isEmpty else { return nil }
            return (letter, items.sorted { $0.createdAt > $1.createdAt })
        }
    }
}

public extension PhotoRecord {
    /// 卡片盒里用的标题：题字，没有题字时用胶卷名。
    var indexTitle: String {
        if let caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return caption }
        return stockName
    }

    var indexLetter: String {
        IndexLetter.letter(for: caption)
    }
}
