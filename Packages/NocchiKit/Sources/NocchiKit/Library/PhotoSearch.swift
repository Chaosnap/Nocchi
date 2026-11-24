import Foundation

/// 相册搜索（软木板、卡片盒、胶卷、日历四种模式共用）。
///
/// 查询按空白切成若干个词（全角空格「　」也算），**每个词**都要在下面至少一处命中：
///
/// - 题字（`caption`）。
/// - 标签：标签和词都先去掉开头的「#」/「＃」再比，所以「阳光」「#阳光」「＃阳光」都能找到标签「阳光」。
///   带「#」的词在其他地方按原样比（「#上海」不会找到地点「上海」）；只有「#」的词（正要输入标签）不参与筛选。
/// - 地点（`location`）。
/// - 胶卷名：记录里的中文名（`stockName`），以及内置胶卷的英文名（`englishName`，只查 `FilmCatalog.builtIn` 里有的胶卷）。
/// - 日期（`displayDate`，公历、当前时区）：「2026」「2026/11/23」「2026-11-23」「2026年11月」「11月」「11月23日」「11/23」，
///   以及「2026/11」「2026.11.23」「2026/11/3」「11/3」这类写法。词是某种写法的开头也算（边打字边筛：
///   「2026/11」→ 这个月的照片），但「1月」不会命中「11月」。英文月份名（至少 3 个字母，可以只打开头）：
///   「nov」「November」→ 11 月的照片（英文界面用）。
/// - 首字母：**单个**英文字母只按卡片盒的首字母（`indexLetter`）找：「w」→「我可以见你吗？」。
///
/// 比较时不分大小写，忽略变音符号和全角 / 半角。两个以上字母的纯拉丁词还会比对题字、标签、地点的
/// 无声调拼音（去掉空格和标点）：「kafei」能找到「咖啡」，「shanghai」能找到「上海」。
public enum PhotoSearch {
    /// 这张照片是否命中查询（空查询命中一切）。
    public static func matches(_ record: PhotoRecord, query: String) -> Bool {
        let tokens = Token.parse(query)
        if tokens.isEmpty { return true }
        return matches(record, tokens: tokens, calendar: PhotoCalendar.localGregorian())
    }

    /// 命中查询的照片，保持原来的顺序（空查询原样返回）。
    public static func filter(_ records: [PhotoRecord], query: String) -> [PhotoRecord] {
        let tokens = Token.parse(query)
        if tokens.isEmpty { return records }
        let calendar = PhotoCalendar.localGregorian()
        return records.filter { matches($0, tokens: tokens, calendar: calendar) }
    }

    // MARK: - 词

    /// 查询里的一个词（已经折叠：小写、无变音符号、半角）。
    private struct Token {
        /// 整个词。
        let text: String
        /// 和标签比的词：去掉开头的「#」/「＃」。
        let tag: String
        /// 单个英文字母（大写）：只按首字母找。
        let letter: String?
        /// 以数字开头：可能是日期。
        let mayBeDate: Bool
        /// 整个词是两个以上的拉丁字母：也比对题字、地点的拼音。
        let pinyinText: Bool
        /// 标签词是两个以上的拉丁字母：也比对标签的拼音。
        let pinyinTag: Bool
        /// 英文月份名（「nov」→ 11）。
        let month: Int?

        static func parse(_ query: String) -> [Token] {
            query.split(whereSeparator: { $0.isWhitespace }).compactMap { Token(String($0)) }
        }

        init?(_ raw: String) {
            let folded = PhotoSearch.fold(raw)
            let tag = PhotoRecord.normalizedTag(folded)
            guard !folded.isEmpty, !tag.isEmpty else { return nil }
            text = folded
            self.tag = tag
            if folded.count == 1, let c = folded.first, c.isASCII, c.isLetter {
                letter = folded.uppercased()
            } else {
                letter = nil
            }
            mayBeDate = folded.first.map { $0.isASCII && $0.isNumber } ?? false
            pinyinText = PhotoSearch.isLatinWord(folded)
            pinyinTag = PhotoSearch.isLatinWord(tag)
            month = PhotoSearch.englishMonth(folded)
        }
    }

    // MARK: - 匹配

    private static func matches(_ record: PhotoRecord, tokens: [Token], calendar: Calendar) -> Bool {
        var dates: [String]?
        for token in tokens {
            if let letter = token.letter {
                if record.indexLetter == letter { continue }
                return false
            }
            if matchesFields(record, token) { continue }
            if let month = token.month, calendar.component(.month, from: record.displayDate) == month { continue }
            if token.mayBeDate {
                let strings = dates ?? dateStrings(for: record.displayDate, calendar: calendar)
                dates = strings
                if strings.contains(where: { $0.hasPrefix(token.text) }) { continue }
            }
            if matchesPinyin(record, token) { continue }
            return false
        }
        return true
    }

    private static func matchesFields(_ record: PhotoRecord, _ token: Token) -> Bool {
        if fieldContains(record.caption, token.text) { return true }
        if record.tags.contains(where: { fieldContains(PhotoRecord.normalizedTag($0), token.tag) }) { return true }
        if fieldContains(record.location, token.text) { return true }
        if fieldContains(record.stockName, token.text) { return true }
        if fieldContains(englishNames[record.stockID], token.text) { return true }
        return false
    }

    private static func matchesPinyin(_ record: PhotoRecord, _ token: Token) -> Bool {
        if token.pinyinText {
            if pinyinContains(record.caption, token.text) { return true }
            if pinyinContains(record.location, token.text) { return true }
        }
        if token.pinyinTag {
            if record.tags.contains(where: { pinyinContains(PhotoRecord.normalizedTag($0), token.tag) }) { return true }
        }
        return false
    }

    private static func fieldContains(_ field: String?, _ needle: String) -> Bool {
        guard let field, !field.isEmpty else { return false }
        return field.range(of: needle, options: foldOptions) != nil
    }

    private static func pinyinContains(_ field: String?, _ needle: String) -> Bool {
        guard let field, let latin = PinyinCache.shared.latin(for: field) else { return false }
        return latin.range(of: needle) != nil
    }

    // MARK: - 折叠、拼音、日期

    private static var foldOptions: String.CompareOptions {
        [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
    }

    /// 小写、去变音符号、全角转半角。
    private static func fold(_ text: String) -> String {
        text.folding(options: foldOptions, locale: nil).lowercased()
    }

    private static let englishMonthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    /// 英文月份名：至少 3 个字母、是某个月份名的开头（「sept」「nov」「november」）。
    static func englishMonth(_ word: String) -> Int? {
        guard word.count >= 3, word.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return englishMonthNames.firstIndex { $0.hasPrefix(word) }.map { $0 + 1 }
    }

    private static func isLatinWord(_ text: String) -> Bool {
        text.count >= 2 && text.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// 无声调拼音（其他文字按拉丁转写）：只留字母和数字，「咖啡，好喝」→「kafeihaohe」。
    private static func latinKey(_ text: String) -> String {
        let latin = text.applyingTransform(.toLatin, reverse: false) ?? text
        let plain = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        return fold(plain).filter { $0.isLetter || $0.isNumber }
    }

    /// 内置胶卷的英文名（按 id）。
    private static let englishNames: [String: String] = {
        var names: [String: String] = [:]
        for stock in FilmCatalog.builtIn where names[stock.id] == nil {
            names[stock.id] = stock.englishName
        }
        return names
    }()

    /// 一天的各种写法（都以数字开头）。词是其中某个的开头就算命中。
    private static func dateStrings(for date: Date, calendar: Calendar) -> [String] {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return [] }
        let yyyy: String = PhotoCalendar.pad(year, 4)
        let mm: String = PhotoCalendar.pad(month, 2)
        let dd: String = PhotoCalendar.pad(day, 2)
        let m = String(month)
        let d = String(day)
        var forms: [String] = [yyyy]
        forms.append("\(yyyy)/\(mm)/\(dd)")
        forms.append("\(yyyy)-\(mm)-\(dd)")
        forms.append("\(yyyy).\(mm).\(dd)")
        forms.append("\(yyyy)/\(m)/\(d)")
        forms.append("\(yyyy)-\(m)-\(d)")
        forms.append("\(yyyy)年\(m)月") // i18n-ok：搜索用的日期写法
        forms.append("\(yyyy)年\(m)月\(d)日") // i18n-ok：搜索用的日期写法
        forms.append("\(m)月") // i18n-ok：搜索用的日期写法
        forms.append("\(m)月\(d)日") // i18n-ok：搜索用的日期写法
        forms.append("\(mm)/\(dd)")
        forms.append("\(m)/\(d)")
        return forms
    }

    /// 拼音转写的小缓存：边打字边搜时，同一段题字不用反复转写。
    private final class PinyinCache: @unchecked Sendable {
        static let shared = PinyinCache()

        private let lock = NSLock()
        private var storage: [String: String] = [:]
        private let limit = 4096

        /// 纯 ASCII 的文字没有拼音可比（直接比对已经覆盖），返回 nil。
        func latin(for text: String) -> String? {
            guard text.unicodeScalars.contains(where: { !$0.isASCII }) else { return nil }
            lock.lock()
            let cached = storage[text]
            lock.unlock()
            if let cached { return cached }
            let value = PhotoSearch.latinKey(text)
            lock.lock()
            if storage.count >= limit { storage.removeAll(keepingCapacity: true) }
            storage[text] = value
            lock.unlock()
            return value
        }
    }
}
