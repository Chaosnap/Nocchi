import Foundation

/// 挂历上的一格（一天）。
public struct CalendarDay: Identifiable, Hashable, Sendable {
    /// 「2026-11-23」（按传入的日历算，前后补齐的日子也有自己的日期）。
    public let id: String
    /// 这一天的零点。
    public let date: Date
    /// 几号。
    public let day: Int
    /// 是不是这个月的（前后补齐的相邻月份为 false）。
    public let isInMonth: Bool
    public let isToday: Bool
    /// 0 = 周一 … 6 = 周日。
    public let weekdayIndex: Int
    /// 这一天的照片，新的在前（按 `displayDate`）。补齐的日子也带着照片。
    public let records: [PhotoRecord]

    public init(id: String, date: Date, day: Int, isInMonth: Bool, isToday: Bool, weekdayIndex: Int, records: [PhotoRecord]) {
        self.id = id
        self.date = date
        self.day = day
        self.isInMonth = isInMonth
        self.isToday = isToday
        self.weekdayIndex = weekdayIndex
        self.records = records
    }
}

/// 挂历的一页（一个月）。
public struct CalendarMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int
    /// 每周 7 天，周一开头，前后用相邻月份补齐；行数正好盖住这个月（4–6 行）。
    public let weeks: [[CalendarDay]]
    /// 本月照片数（只算本月的日子）。
    public let photoCount: Int
    /// 本月用了几种胶卷（不同的 `stockID`）。
    public let stockCount: Int
    /// 本月最常写的标签（不带「#」）；没有标签时为 nil。
    public let topTag: String?

    public init(year: Int, month: Int, weeks: [[CalendarDay]], photoCount: Int, stockCount: Int, topTag: String?) {
        self.year = year
        self.month = month
        self.weeks = weeks
        self.photoCount = photoCount
        self.stockCount = stockCount
        self.topTag = topTag
    }
}

/// 复古挂历的数据：把照片按天放进一个月的格子里。
public enum PhotoCalendar {
    /// 某年某月的挂历页。
    ///
    /// - 所有日期运算都用传入的 `calendar`（含它的时区）；不管 `firstWeekday` 是什么，周一总在第一列。
    /// - 月份超出 1…12 时顺延（2026 年 13 月 = 2027 年 1 月），返回值里是顺延后的年月。
    /// - 照片按 `displayDate` 放进对应的格子；统计（张数、胶卷数、最常写的标签）只算本月的日子。
    /// - 最常写的标签：标签先经 `PhotoRecord.normalizedTag` 规整，同一张照片里重复的只算一次；
    ///   次数相同时取「新 → 旧」顺序里先出现的那个。
    public static func month(year: Int, month: Int, records: [PhotoRecord], calendar: Calendar = .current, today: Date = Date()) -> CalendarMonth {
        guard let first = firstDay(year: year, month: month, calendar: calendar) else {
            return CalendarMonth(year: year, month: month, weeks: [], photoCount: 0, stockCount: 0, topTag: nil)
        }
        let header = calendar.dateComponents([.year, .month], from: first)
        let shownYear = header.year ?? year
        let shownMonth = header.month ?? month
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = mondayIndex(of: first, calendar: calendar)
        let cellCount = (lead + dayCount + 6) / 7 * 7

        let gridStart = calendar.startOfDay(for: addDays(-lead, to: first, calendar: calendar))
        let gridEnd = addDays(cellCount, to: gridStart, calendar: calendar)

        var buckets: [String: [PhotoRecord]] = [:]
        for record in records where record.displayDate >= gridStart && record.displayDate < gridEnd {
            buckets[dayKey(record.displayDate, calendar: calendar), default: []].append(record)
        }

        var days: [CalendarDay] = []
        days.reserveCapacity(cellCount)
        for offset in 0..<cellCount {
            let date = calendar.startOfDay(for: addDays(offset, to: gridStart, calendar: calendar))
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let key = dayKey(parts)
            days.append(CalendarDay(
                id: key,
                date: date,
                day: parts.day ?? 0,
                isInMonth: parts.year == shownYear && parts.month == shownMonth,
                isToday: calendar.isDate(date, inSameDayAs: today),
                weekdayIndex: offset % 7,
                records: (buckets[key] ?? []).sorted(by: newestFirst)
            ))
        }

        let weeks = stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
        let inMonth = days.filter { $0.isInMonth }.flatMap { $0.records }.sorted(by: newestFirst)
        return CalendarMonth(
            year: shownYear,
            month: shownMonth,
            weeks: weeks,
            photoCount: inMonth.count,
            stockCount: Set(inMonth.map { $0.stockID }).count,
            topTag: topTag(in: inMonth)
        )
    }

    // MARK: - 内部

    /// 这个月 1 号零点（月份超出范围时顺延）。
    private static func firstDay(year: Int, month: Int, calendar: Calendar) -> Date? {
        guard let january = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let first = calendar.date(byAdding: .month, value: month - 1, to: january) else {
            return nil
        }
        return calendar.startOfDay(for: first)
    }

    /// 按日历加减天数（夏令时也是「一天」）；万一算不出来就按 24 小时兜底。
    private static func addDays(_ days: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * 86_400)
    }

    /// 0 = 周一 … 6 = 周日（`.weekday` 是 1 = 周日 … 7 = 周六）。
    private static func mondayIndex(of date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// 次数最多的标签；平手时取在 `records`（新 → 旧）里先出现的。
    private static func topTag(in records: [PhotoRecord]) -> String? {
        var counts: [String: Int] = [:]
        var firstSeen: [String] = []
        for record in records {
            var seen = Set<String>()
            for raw in record.tags {
                let tag = PhotoRecord.normalizedTag(raw)
                guard !tag.isEmpty, seen.insert(tag).inserted else { continue }
                if counts[tag] == nil { firstSeen.append(tag) }
                counts[tag, default: 0] += 1
            }
        }
        guard let best = counts.values.max() else { return nil }
        return firstSeen.first { counts[$0] == best }
    }
}

// MARK: - 相册分组共用的小工具（`FilmStrips`、`PhotoSearch` 也用）

extension PhotoCalendar {
    /// 左侧补零：`pad(7, 2)` → 「07」。
    static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        guard digits.count < width else { return digits }
        return String(repeating: "0", count: width - digits.count) + digits
    }

    /// 公历、当前时区（胶片条的月份、搜索里的日期写法）。
    static func localGregorian() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone.current
        return calendar
    }

    /// 「2026-11-23」。
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        dayKey(calendar.dateComponents([.year, .month, .day], from: date))
    }

    static func dayKey(_ parts: DateComponents) -> String {
        let year: String = pad(parts.year ?? 0, 4)
        let month: String = pad(parts.month ?? 0, 2)
        let day: String = pad(parts.day ?? 0, 2)
        return "\(year)-\(month)-\(day)"
    }

    /// 「2026-11」。
    static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year: String = pad(parts.year ?? 0, 4)
        let month: String = pad(parts.month ?? 0, 2)
        return "\(year)-\(month)"
    }

    /// 新 → 旧：按 `displayDate`，再按 `createdAt`，最后按 id（结果稳定）。
    static func newestFirst(_ a: PhotoRecord, _ b: PhotoRecord) -> Bool {
        if a.displayDate != b.displayDate { return a.displayDate > b.displayDate }
        if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        return a.id.uuidString < b.id.uuidString
    }

    /// 旧 → 新：按 `displayDate`，再按 `createdAt`，最后按 id（结果稳定）。
    static func oldestFirst(_ a: PhotoRecord, _ b: PhotoRecord) -> Bool {
        if a.displayDate != b.displayDate { return a.displayDate < b.displayDate }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.id.uuidString < b.id.uuidString
    }
}
