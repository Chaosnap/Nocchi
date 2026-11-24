import Foundation

/// 卡片盒的归档方式：按题字的首字母，或者按拍摄日期（`displayDate`）的年、月、日。
public enum CardIndexMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case letter
    case year
    case month
    case day

    public var id: String { rawValue }
}

/// 卡片盒里的一格：一张分隔卡和它的标签。
public struct CardTab: Hashable, Sendable, Identifiable {
    public var id: String { key }
    /// 第几张分隔卡：0 = 最前面（首字母时是 A），26 = 最后面（#）。
    public let slot: Int
    /// 这一格的键：「W」「2026」「2026-11」「2026-11-24」，放不下的是 `CardIndex.olderKey`。
    public let key: String
    /// 印在分隔卡标签上的短字：「W」「2026」「11月」/「Nov」「11/24」「更早」/「Older」。
    public let label: String
    /// 吊牌和摊开说明里的完整说法：「W」「2026 年」「2026 年 11 月」/「November 2026」……
    public let title: String
    /// 这一格有几张照片。
    public let count: Int

    public init(slot: Int, key: String, label: String, title: String, count: Int) {
        self.slot = slot
        self.key = key
        self.label = label
        self.title = title
        self.count = count
    }
}

/// 照片按某种方式分进卡片盒的结果。
public struct CardIndexLayout: Sendable {
    public let mode: CardIndexMode
    /// 用到的分隔卡，按 `slot` 从前往后。首字母时 27 张都在（没有照片的 count 为 0）；按日期时只有有照片的格子。
    public let tabs: [CardTab]
    /// 每张照片放在哪一格（`CardTab.key`）。
    public let keys: [UUID: String]

    private let bySlot: [String: Int]

    public init(mode: CardIndexMode, tabs: [CardTab], keys: [UUID: String]) {
        self.mode = mode
        self.tabs = tabs
        self.keys = keys
        var slots: [String: Int] = [:]
        for tab in tabs {
            slots[tab.key] = tab.slot
        }
        bySlot = slots
    }

    public static let empty = CardIndexLayout(mode: .letter, tabs: [], keys: [:])

    public func tab(forKey key: String) -> CardTab? {
        tabs.first { $0.key == key }
    }

    /// 这张照片所在的格子。
    public func key(for record: PhotoRecord) -> String? {
        keys[record.id]
    }

    /// 这张照片所在分隔卡的位置（没有分到格子时放在最后一格）。
    public func slot(for record: PhotoRecord) -> Int {
        keys[record.id].flatMap { bySlot[$0] } ?? (CardIndex.slotCount - 1)
    }

    /// 这张照片的卡片自己那个小标签上印什么（和所在分隔卡一样）。
    public func label(for record: PhotoRecord) -> String {
        keys[record.id].flatMap { tab(forKey: $0)?.label } ?? IndexLetter.other
    }

    public func count(forKey key: String) -> Int {
        tab(forKey: key)?.count ?? 0
    }
}

/// 把照片分进卡片盒的 27 张分隔卡。
///
/// - 首字母：A–Z 与 #，固定 27 格（`IndexLetter`）。
/// - 年 / 月 / 日：有照片的年份、年月、日子，新的在最前面；超过 27 个时，前 26 个各占一格，
///   更早的都放进最后一格「更早」。没用到的分隔卡标签空着。
///
/// 日期按公历、当前时区（和搜索、挂历一样）。标签文字随界面语言：中文「11月」，英文「Nov」。
public enum CardIndex {
    /// 盒子里分隔卡的张数（Blender 模型里就是 27 张）。
    public static let slotCount = 27
    /// 放不下的、更早的照片那一格。
    public static let olderKey = "older"

    public static func layout(
        for records: [PhotoRecord],
        mode: CardIndexMode,
        language: UILanguage = .current,
        calendar: Calendar? = nil
    ) -> CardIndexLayout {
        switch mode {
        case .letter:
            return letterLayout(records)
        case .year, .month, .day:
            return dateLayout(records, mode: mode, language: language, calendar: calendar ?? PhotoCalendar.localGregorian())
        }
    }

    // MARK: - 首字母

    private static func letterLayout(_ records: [PhotoRecord]) -> CardIndexLayout {
        var counts: [String: Int] = [:]
        var keys: [UUID: String] = [:]
        for record in records {
            let letter = record.indexLetter
            counts[letter, default: 0] += 1
            keys[record.id] = letter
        }
        let tabs = IndexLetter.all.enumerated().map { slot, letter in
            CardTab(slot: slot, key: letter, label: letter, title: letter, count: counts[letter] ?? 0)
        }
        return CardIndexLayout(mode: .letter, tabs: tabs, keys: keys)
    }

    // MARK: - 年月日

    private struct DateParts: Hashable {
        let year: Int
        let month: Int
        let day: Int
    }

    private static func dateLayout(_ records: [PhotoRecord], mode: CardIndexMode, language: UILanguage, calendar: Calendar) -> CardIndexLayout {
        var partsByKey: [String: DateParts] = [:]
        var rawKeys: [UUID: String] = [:]
        var counts: [String: Int] = [:]
        for record in records {
            let c = calendar.dateComponents([.year, .month, .day], from: record.displayDate)
            let parts = DateParts(year: c.year ?? 0, month: c.month ?? 1, day: c.day ?? 1)
            let key = dateKey(parts, mode: mode)
            partsByKey[key] = parts
            rawKeys[record.id] = key
            counts[key, default: 0] += 1
        }
        // 键是补零的「yyyy」「yyyy-MM」「yyyy-MM-dd」，按字符串倒序就是新的在前。
        let ordered = partsByKey.keys.sorted(by: >)
        let overflow = ordered.count > slotCount
        let kept = overflow ? Array(ordered.prefix(slotCount - 1)) : ordered
        let keptSet = Set(kept)

        var tabs: [CardTab] = []
        for (slot, key) in kept.enumerated() {
            guard let parts = partsByKey[key] else { continue }
            tabs.append(CardTab(
                slot: slot,
                key: key,
                label: label(parts, mode: mode, language: language),
                title: title(parts, mode: mode, language: language),
                count: counts[key] ?? 0
            ))
        }
        var keys = rawKeys
        if overflow {
            var olderCount = 0
            for (id, key) in rawKeys where !keptSet.contains(key) {
                keys[id] = olderKey
                olderCount += 1
            }
            let older = olderLabel(language)
            tabs.append(CardTab(slot: slotCount - 1, key: olderKey, label: older, title: older, count: olderCount))
        }
        return CardIndexLayout(mode: mode, tabs: tabs, keys: keys)
    }

    private static func dateKey(_ p: DateParts, mode: CardIndexMode) -> String {
        let yyyy = PhotoCalendar.pad(p.year, 4)
        switch mode {
        case .year: return yyyy
        case .month: return "\(yyyy)-\(PhotoCalendar.pad(p.month, 2))"
        default: return "\(yyyy)-\(PhotoCalendar.pad(p.month, 2))-\(PhotoCalendar.pad(p.day, 2))"
        }
    }

    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let longMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    private static func monthName(_ month: Int, short: Bool) -> String {
        let names = short ? shortMonths : longMonths
        return names[min(max(month, 1), 12) - 1]
    }

    /// 分隔卡标签上的短字（标签很小，最多 5 个字符）。
    private static func label(_ p: DateParts, mode: CardIndexMode, language: UILanguage) -> String {
        switch mode {
        case .year:
            return String(p.year)
        case .month:
            return language.isEnglish ? monthName(p.month, short: true) : "\(p.month)月" // i18n-ok：按语言分别生成
        default:
            return "\(p.month)/\(p.day)"
        }
    }

    /// 吊牌上的完整说法。
    private static func title(_ p: DateParts, mode: CardIndexMode, language: UILanguage) -> String {
        if language.isEnglish {
            switch mode {
            case .year: return String(p.year)
            case .month: return "\(monthName(p.month, short: false)) \(p.year)"
            default: return "\(monthName(p.month, short: false)) \(p.day), \(p.year)"
            }
        }
        switch mode {
        case .year: return "\(p.year) 年" // i18n-ok
        case .month: return "\(p.year) 年 \(p.month) 月" // i18n-ok
        default: return "\(p.year) 年 \(p.month) 月 \(p.day) 日" // i18n-ok
        }
    }

    private static func olderLabel(_ language: UILanguage) -> String {
        language.isEnglish ? "Older" : "更早" // i18n-ok
    }
}
