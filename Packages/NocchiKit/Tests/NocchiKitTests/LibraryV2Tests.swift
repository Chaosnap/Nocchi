import CoreGraphics
import XCTest
@testable import NocchiKit

// v0.2 相册：搜索、胶片条、挂历；以及照片记录新字段的兼容性、相纸规格、胶卷分组。
// 辅助函数都是各个测试类里的 private static，不在文件顶层加名字（避免和其他测试文件撞名）。

// MARK: - 搜索

final class LibraryV2SearchTests: XCTestCase {
    private static let stock = FilmStock(id: "libv2-sakura", name: "樱雨 200", englishName: "Sakura Rain 200")

    /// PhotoSearch 按「公历 + 当前时区」解释日期；测试用同一个日历造时间，结果与机器所在时区无关。
    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func record(
        caption: String? = nil,
        location: String? = nil,
        tags: [String] = [],
        stock: FilmStock = LibraryV2SearchTests.stock,
        createdAt: Date = LibraryV2SearchTests.date(2026, 11, 23),
        takenAt: Date? = nil
    ) -> PhotoRecord {
        PhotoRecord(
            createdAt: createdAt,
            source: .selfie,
            body: .instant,
            stock: stock,
            seed: 1,
            caption: caption,
            takenAt: takenAt,
            location: location,
            tags: tags
        )
    }

    func testChineseSubstringOfCaption() {
        let record = Self.record(caption: "今天的咖啡很好喝")
        XCTAssertTrue(PhotoSearch.matches(record, query: "咖啡"))
        XCTAssertTrue(PhotoSearch.matches(record, query: "好喝"))
        XCTAssertTrue(PhotoSearch.matches(record, query: "咖"))
        XCTAssertFalse(PhotoSearch.matches(record, query: "奶茶"))
        XCTAssertFalse(PhotoSearch.matches(Self.record(), query: "咖啡"), "没有题字")
    }

    func testTagsMatchWithOrWithoutHash() {
        let record = Self.record(tags: ["#阳光", " 咖啡 "])
        for query in ["阳光", "#阳光", "＃阳光", "##阳光", "阳", "咖啡", "#咖啡", "#咖"] {
            XCTAssertTrue(PhotoSearch.matches(record, query: query), query)
        }
        XCTAssertFalse(PhotoSearch.matches(record, query: "雨天"))
        XCTAssertFalse(PhotoSearch.matches(record, query: "#雨天"))

        let place = Self.record(location: "上海")
        XCTAssertTrue(PhotoSearch.matches(place, query: "上海"))
        XCTAssertFalse(PhotoSearch.matches(place, query: "#上海"), "带 # 的词只按标签找")
        XCTAssertTrue(PhotoSearch.matches(place, query: "#"), "只有 # 的词（正要输入标签）不筛选")
        XCTAssertTrue(PhotoSearch.matches(place, query: "上海 ＃"))
    }

    func testLocationIgnoresCaseDiacriticsAndWidth() {
        let record = Self.record(caption: "Café Latte", location: "Zürich")
        for query in ["zurich", "ZÜRICH", "Zur", "cafe", "LATTE", "ｃａｆｅ"] {
            XCTAssertTrue(PhotoSearch.matches(record, query: query), query)
        }
        XCTAssertFalse(PhotoSearch.matches(record, query: "geneva"))
        XCTAssertTrue(PhotoSearch.matches(Self.record(location: "上海"), query: "上海"))
    }

    func testStockNamesChineseAndBuiltInEnglish() {
        let custom = Self.record()
        XCTAssertTrue(PhotoSearch.matches(custom, query: "樱雨"))
        XCTAssertTrue(PhotoSearch.matches(custom, query: "樱雨 200"))
        XCTAssertFalse(PhotoSearch.matches(custom, query: "sakura"), "英文名只查内置胶卷")

        let builtIn = FilmCatalog.defaultStock
        let english = builtIn.englishName.split(separator: " ").first.map { String($0).lowercased() } ?? ""
        XCTAssertGreaterThanOrEqual(english.count, 2, "默认胶卷要有英文名")
        let record = Self.record(caption: "海边", stock: builtIn)
        XCTAssertTrue(PhotoSearch.matches(record, query: english), english)
        XCTAssertTrue(PhotoSearch.matches(record, query: english.uppercased()), english)
        XCTAssertTrue(PhotoSearch.matches(record, query: builtIn.name))
    }

    func testDateFormsUseDisplayDate() {
        // 拍摄时间改过：按 takenAt（displayDate）找，不按 createdAt。
        let record = Self.record(createdAt: Self.date(2025, 3, 5), takenAt: Self.date(2026, 11, 23))
        let hits = [
            "2026", "2026/11/23", "2026-11-23", "2026年11月", "11月", "11月23日", "11/23",
            "2026/11", "2026年", "2026年11月23日", "2026.11.23", "２０２６"
        ]
        for query in hits {
            XCTAssertTrue(PhotoSearch.matches(record, query: query), query)
        }
        for query in ["2025", "3月", "1月", "12月", "11月24日", "11/24", "2026/12", "2026-11-24"] {
            XCTAssertFalse(PhotoSearch.matches(record, query: query), query)
        }

        let january = Self.record(createdAt: Self.date(2026, 1, 5))
        for query in ["1月", "1月5日", "01/05", "1/5", "2026/1/5", "2026-01-05", "2026年1月"] {
            XCTAssertTrue(PhotoSearch.matches(january, query: query), query)
        }
        XCTAssertFalse(PhotoSearch.matches(january, query: "11月"))
    }

    func testPinyinFindsChinese() {
        let record = Self.record(caption: "咖啡", location: "上海", tags: ["阳光"])
        for query in ["kafei", "KaFei", "kāfēi", "ka fei", "shanghai", "yangguang", "#yangguang"] {
            XCTAssertTrue(PhotoSearch.matches(record, query: query), query)
        }
        for query in ["beijing", "kafeiting", "#kafei", "#shanghai"] {
            XCTAssertFalse(PhotoSearch.matches(record, query: query), query)
        }
    }

    func testSingleLetterMatchesIndexLetterOnly() {
        let chinese = Self.record(caption: "我可以见你吗？")
        let latin = Self.record(caption: "Flowers from Karin")
        XCTAssertTrue(PhotoSearch.matches(chinese, query: "w"))
        XCTAssertTrue(PhotoSearch.matches(chinese, query: "W"))
        XCTAssertTrue(PhotoSearch.matches(chinese, query: "ｗ"))
        XCTAssertFalse(PhotoSearch.matches(chinese, query: "k"), "单个字母不比拼音")
        XCTAssertTrue(PhotoSearch.matches(latin, query: "f"))
        XCTAssertFalse(PhotoSearch.matches(latin, query: "o"), "单个字母不比题字里的字母")
        XCTAssertFalse(PhotoSearch.matches(latin, query: "k"))
        XCTAssertFalse(PhotoSearch.matches(Self.record(), query: "a"), "没有题字的照片归在「#」")
        XCTAssertEqual(PhotoSearch.filter([latin, chinese], query: "w").map(\.id), [chinese.id])
    }

    func testEveryTokenMustMatch() {
        let both = Self.record(caption: "咖啡", location: "上海")
        let other = Self.record(caption: "咖啡", location: "北京")
        XCTAssertTrue(PhotoSearch.matches(both, query: "咖啡 上海"))
        XCTAssertFalse(PhotoSearch.matches(other, query: "咖啡 上海"))
        XCTAssertTrue(PhotoSearch.matches(both, query: "咖啡\u{3000}上海"), "全角空格也是分隔")
        XCTAssertTrue(PhotoSearch.matches(both, query: "  上海\t咖啡 2026 "))
        XCTAssertFalse(PhotoSearch.matches(both, query: "咖啡 上海 2025"))
        XCTAssertEqual(PhotoSearch.filter([other, both], query: "咖啡 上海").map(\.id), [both.id])
    }

    func testEmptyQueryMatchesEverythingAndFilterKeepsOrder() {
        let records = [
            Self.record(caption: "咖啡 · 一"),
            Self.record(caption: "奶茶"),
            Self.record(caption: "咖啡 · 二"),
            Self.record(caption: "咖啡 · 三")
        ]
        for query in ["", "   ", "\u{3000}", "\n\t"] {
            XCTAssertTrue(PhotoSearch.matches(records[1], query: query))
            XCTAssertEqual(PhotoSearch.filter(records, query: query).map(\.id), records.map(\.id))
        }
        XCTAssertEqual(PhotoSearch.filter(records, query: "咖啡").map(\.id), [records[0].id, records[2].id, records[3].id])
        let reversed = Array(records.reversed())
        XCTAssertEqual(PhotoSearch.filter(reversed, query: "咖啡").map(\.id), [records[3].id, records[2].id, records[0].id])
        XCTAssertTrue(PhotoSearch.filter(records, query: "雨天").isEmpty)
    }
}

// MARK: - 胶片条

final class LibraryV2FilmStripTests: XCTestCase {
    private static let stockX = FilmStock(id: "libv2-x", name: "测试 X")
    private static let stockY = FilmStock(id: "libv2-y", name: "测试 Y")

    /// 胶片条按「公历 + 当前时区」分月；测试用同一个日历造时间。
    private static func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// 固定的 UUID：序号越大，uuidString 越大。
    private static func uuid(_ n: Int) -> UUID {
        let digits = String(n)
        let tail = String(repeating: "0", count: max(0, 12 - digits.count)) + digits
        return UUID(uuidString: "00000000-0000-4000-8000-" + tail)!
    }

    private static func roll(
        _ n: Int,
        month: Int,
        day: Int,
        stock: FilmStock = LibraryV2FilmStripTests.stockX,
        negatives: Int = 1
    ) -> PhotoRecord {
        PhotoRecord(
            id: uuid(n),
            createdAt: date(month, day),
            source: .screen,
            body: .instant,
            stock: stock,
            seed: UInt64(n),
            negatives: (0..<negatives).map { "\(n)-\($0).jpg" }
        )
    }

    private static func booth(_ n: Int, month: Int, day: Int, format: FilmFormat = .boothStrip) -> PhotoRecord {
        var record = PhotoRecord(
            id: uuid(n),
            createdAt: date(month, day),
            source: .booth,
            body: .photoBooth,
            stock: stockX,
            seed: UInt64(n),
            negatives: (0..<4).map { "\(n)-\($0).jpg" }
        )
        record.format = format
        return record
    }

    func testRollsAreChunkedOldestFirst() {
        let records = (1...6).map { Self.roll($0, month: 11, day: $0) }
        let strips = FilmStrips.make(from: Array(records.reversed()))
        XCTAssertEqual(strips.map(\.kind), [.roll, .roll])
        XCTAssertEqual(strips.map { $0.frames.map(\.recordID) }, [records[0..<4].map(\.id), records[4..<6].map(\.id)])
        XCTAssertTrue(strips.flatMap(\.frames).allSatisfy { $0.negativeIndex == 0 })
        XCTAssertEqual(strips.map(\.firstFrameNumber), [1, 5])
        XCTAssertEqual(strips.map(\.id), ["roll-" + records[0].id.uuidString, "roll-" + records[4].id.uuidString])
        XCTAssertEqual(strips.map(\.monthKey), ["2026-11", "2026-11"])
        XCTAssertEqual(strips.map(\.startDate), [records[0].displayDate, records[4].displayDate])
        XCTAssertEqual(strips.map(\.stockID), [Self.stockX.id, Self.stockX.id])
        XCTAssertEqual(strips.map(\.stockName), [Self.stockX.name, Self.stockX.name])
    }

    func testBoothPrintsAreTheirOwnStrips() {
        let first = Self.roll(1, month: 11, day: 1)
        let stripPrint = Self.booth(2, month: 11, day: 2)
        let second = Self.roll(3, month: 11, day: 3)
        let gridPrint = Self.booth(4, month: 11, day: 4, format: .boothGrid)
        let strips = FilmStrips.make(from: [gridPrint, second, stripPrint, first])
        XCTAssertEqual(strips.map(\.kind), [.roll, .booth, .booth])
        guard strips.count == 3 else { return }

        XCTAssertEqual(strips[0].frames.map(\.recordID), [first.id, second.id], "大头贴夹在中间不打断同一卷胶卷")
        XCTAssertEqual(strips[0].firstFrameNumber, 1)
        XCTAssertEqual(strips[1].id, "booth-" + stripPrint.id.uuidString)
        XCTAssertEqual(strips[1].frames, (0..<4).map { FilmStrip.Frame(recordID: stripPrint.id, negativeIndex: $0) })
        XCTAssertEqual(strips[1].firstFrameNumber, 1)
        XCTAssertEqual(strips[1].monthKey, "2026-11")
        XCTAssertEqual(strips[1].startDate, stripPrint.displayDate)
        XCTAssertEqual(strips[2].id, "booth-" + gridPrint.id.uuidString)
        XCTAssertEqual(strips[2].frames.map(\.negativeIndex), [0, 1, 2, 3])
        XCTAssertEqual(Set(strips.map(\.id)).count, strips.count)
    }

    func testStripsNeverCrossMonths() {
        let records = [
            Self.roll(1, month: 10, day: 30), Self.roll(2, month: 10, day: 31),
            Self.roll(3, month: 11, day: 1), Self.roll(4, month: 11, day: 2)
        ]
        let strips = FilmStrips.make(from: records)
        XCTAssertEqual(strips.map(\.monthKey), ["2026-10", "2026-11"])
        XCTAssertEqual(strips.map { $0.frames.map(\.recordID) }, [[records[0].id, records[1].id], [records[2].id, records[3].id]])
        XCTAssertEqual(strips.map(\.firstFrameNumber), [1, 1], "每个月从 1 数起")
    }

    func testStockChangeStartsANewStripButNumbersKeepCounting() {
        let records = [
            Self.roll(1, month: 11, day: 1), Self.roll(2, month: 11, day: 2),
            Self.roll(3, month: 11, day: 3, stock: Self.stockY),
            Self.roll(4, month: 11, day: 4), Self.roll(5, month: 11, day: 5)
        ]
        let strips = FilmStrips.make(from: records)
        XCTAssertEqual(strips.map { $0.frames.count }, [2, 1, 2])
        XCTAssertEqual(strips.map(\.stockID), [Self.stockX.id, Self.stockY.id, Self.stockX.id])
        XCTAssertEqual(strips.map(\.stockName), [Self.stockX.name, Self.stockY.name, Self.stockX.name])
        XCTAssertEqual(strips.map(\.firstFrameNumber), [1, 3, 4])
        XCTAssertEqual(strips.map(\.id), ["roll-" + records[0].id.uuidString, "roll-" + records[2].id.uuidString, "roll-" + records[3].id.uuidString])
    }

    func testRecordsWithoutNegativesAreSkipped() {
        let first = Self.roll(1, month: 11, day: 1)
        let blank = Self.roll(2, month: 11, day: 2, negatives: 0)
        var blankBooth = Self.booth(3, month: 11, day: 3)
        blankBooth.negatives = []
        let second = Self.roll(4, month: 11, day: 4)
        let strips = FilmStrips.make(from: [first, blank, blankBooth, second])
        XCTAssertEqual(strips.map { $0.frames.map(\.recordID) }, [[first.id, second.id]])
        XCTAssertEqual(strips.map(\.firstFrameNumber), [1], "跳过的照片不占帧号")
        XCTAssertTrue(FilmStrips.make(from: []).isEmpty)
        XCTAssertTrue(FilmStrips.make(from: [blank, blankBooth]).isEmpty)
    }

    func testOrderFollowsDisplayDateThenCreatedAtThenID() {
        // createdAt 是 11 月 20 日，但拍摄时间改成了 11 月 2 日。
        var retimed = Self.roll(1, month: 11, day: 20)
        retimed.takenAt = Self.date(11, 2)
        let middle = Self.roll(2, month: 11, day: 5)
        // 同一个拍摄时间：先按 createdAt（earlier 的 id 更大，确认不是按 id 排的）。
        var earlier = Self.roll(9, month: 11, day: 6)
        var later = Self.roll(8, month: 11, day: 7)
        earlier.takenAt = Self.date(11, 8)
        later.takenAt = Self.date(11, 8)
        // 时间完全相同：按 id。
        let tieA = Self.roll(3, month: 11, day: 9)
        let tieB = Self.roll(4, month: 11, day: 9)

        let strips = FilmStrips.make(from: [tieB, later, middle, tieA, earlier, retimed], framesPerStrip: 10)
        XCTAssertEqual(strips.map { $0.frames.map(\.recordID) }, [[retimed.id, middle.id, earlier.id, later.id, tieA.id, tieB.id]])
        XCTAssertEqual(strips.first?.startDate, Self.date(11, 2))
    }

    func testFramesPerStripBelowOneMeansOne() {
        let records = (1...3).map { Self.roll($0, month: 11, day: $0) }
        XCTAssertEqual(FilmStrips.make(from: records, framesPerStrip: 0).map(\.firstFrameNumber), [1, 2, 3])
        XCTAssertEqual(FilmStrips.make(from: records, framesPerStrip: 2).map { $0.frames.count }, [2, 1])
    }
}

// MARK: - 挂历

final class LibraryV2CalendarTests: XCTestCase {
    /// 固定时区；故意设成周日开头，挂历仍然要周一开头。
    private static var shanghai: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func record(_ date: Date, stock: String, tags: [String] = [], takenAt: Date? = nil) -> PhotoRecord {
        PhotoRecord(
            createdAt: date,
            source: .screen,
            body: .instant,
            stock: FilmStock(id: stock, name: stock),
            seed: 1,
            takenAt: takenAt,
            tags: tags
        )
    }

    func testNovember2026StartsOnSunday() {
        let calendar = Self.shanghai
        let today = Self.date(calendar, 2026, 11, 23, hour: 9)
        let page = PhotoCalendar.month(year: 2026, month: 11, records: [], calendar: calendar, today: today)
        XCTAssertEqual(page.year, 2026)
        XCTAssertEqual(page.month, 11)
        XCTAssertEqual(page.weeks.count, 6)
        XCTAssertTrue(page.weeks.allSatisfy { $0.count == 7 })
        guard page.weeks.count == 6 else { return }

        let first = page.weeks[0]
        XCTAssertEqual(first.map(\.day), [26, 27, 28, 29, 30, 31, 1])
        XCTAssertEqual(first.map(\.isInMonth), [false, false, false, false, false, false, true])
        XCTAssertEqual(first.map(\.id), ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
        XCTAssertEqual(first.last?.date, Self.date(calendar, 2026, 11, 1, hour: 0), "每格的 date 是那天零点")

        let last = page.weeks[5]
        XCTAssertEqual(last.map(\.day), [30, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(last.map(\.isInMonth), [true, false, false, false, false, false, false])
        XCTAssertEqual(last.last?.id, "2026-12-06")

        let days = Array(page.weeks.joined())
        XCTAssertTrue(page.weeks.allSatisfy { $0.map(\.weekdayIndex) == Array(0..<7) })
        XCTAssertEqual(days.filter(\.isInMonth).map(\.day), Array(1...30))
        XCTAssertEqual(Set(days.map(\.id)).count, 42)
        XCTAssertEqual(days.filter(\.isToday).map(\.id), ["2026-11-23"])
        XCTAssertEqual(days.first(where: \.isToday)?.weekdayIndex, 0, "2026-11-23 是周一")
        XCTAssertEqual(page.photoCount, 0)
        XCTAssertEqual(page.stockCount, 0)
        XCTAssertNil(page.topTag)

        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let again = PhotoCalendar.month(year: 2026, month: 11, records: [], calendar: mondayFirst, today: today)
        XCTAssertEqual(again.weeks.map { $0.map(\.id) }, page.weeks.map { $0.map(\.id) }, "和系统的一周第一天无关")
    }

    func testRecordsCountsAndTopTag() {
        let calendar = Self.shanghai
        let morning = Self.record(Self.date(calendar, 2026, 11, 23, hour: 9), stock: "a", tags: ["阳光", "咖啡"])
        let evening = Self.record(Self.date(calendar, 2026, 11, 23, hour: 18), stock: "b", tags: ["#阳光"])
        let early = Self.record(Self.date(calendar, 2026, 11, 5), stock: "a", tags: ["咖啡"])
        let leading = Self.record(Self.date(calendar, 2026, 10, 28), stock: "c", tags: ["咖啡", "雨天"])
        let outside = Self.record(Self.date(calendar, 2026, 12, 25), stock: "d", tags: ["咖啡"])
        // 十一月拍的，但拍摄时间改成了 10 月 30 日：按 displayDate 放进 10 月 30 日那一格，不算进十一月。
        let retimed = Self.record(
            Self.date(calendar, 2026, 11, 10), stock: "e", tags: ["咖啡"],
            takenAt: Self.date(calendar, 2026, 10, 30)
        )

        let page = PhotoCalendar.month(
            year: 2026,
            month: 11,
            records: [early, leading, morning, outside, retimed, evening],
            calendar: calendar,
            today: Self.date(calendar, 2026, 11, 23)
        )
        var byID: [String: CalendarDay] = [:]
        for day in page.weeks.joined() { byID[day.id] = day }

        XCTAssertEqual(byID["2026-11-23"]?.records.map(\.id), [evening.id, morning.id], "同一天新的在前")
        XCTAssertEqual(byID["2026-11-05"]?.records.map(\.id), [early.id])
        XCTAssertEqual(byID["2026-10-28"]?.records.map(\.id), [leading.id], "补齐的日子也带着照片")
        XCTAssertEqual(byID["2026-10-28"]?.isInMonth, false)
        XCTAssertEqual(byID["2026-10-30"]?.records.map(\.id), [retimed.id])
        XCTAssertEqual(byID["2026-11-10"]?.records.count, 0)
        XCTAssertNil(byID["2026-12-25"], "挂历页之外的日子不出现")

        XCTAssertEqual(page.photoCount, 3)
        XCTAssertEqual(page.stockCount, 2)
        // 本月：阳光 2 次（evening、morning），咖啡 2 次（morning、early）；平手时取「新 → 旧」里先出现的。
        XCTAssertEqual(page.topTag, "阳光")
    }

    func testTopTagCountsEachPhotoOnce() {
        let calendar = Self.shanghai
        let today = Self.date(calendar, 2026, 11, 23)
        let records = [
            Self.record(Self.date(calendar, 2026, 11, 2), stock: "a", tags: ["旅行"]),
            Self.record(Self.date(calendar, 2026, 11, 20), stock: "a", tags: ["夜晚", "#夜晚", " 夜晚 "]),
            Self.record(Self.date(calendar, 2026, 11, 3), stock: "a", tags: ["＃旅行"])
        ]
        let page = PhotoCalendar.month(year: 2026, month: 11, records: records, calendar: calendar, today: today)
        XCTAssertEqual(page.topTag, "旅行", "同一张照片里重复的标签只算一次")
        XCTAssertEqual(page.photoCount, 3)
        XCTAssertEqual(page.stockCount, 1)

        let blank = Self.record(Self.date(calendar, 2026, 11, 2), stock: "a", tags: ["  ", "#"])
        let untagged = PhotoCalendar.month(year: 2026, month: 11, records: [blank], calendar: calendar, today: today)
        XCTAssertNil(untagged.topTag)
        XCTAssertEqual(untagged.photoCount, 1)
    }

    func testWeekCountFollowsTheMonth() {
        let calendar = Self.shanghai
        let today = Self.date(calendar, 2026, 11, 23)
        let june = PhotoCalendar.month(year: 2026, month: 6, records: [], calendar: calendar, today: today)
        XCTAssertEqual(june.weeks.count, 5, "2026 年 6 月 1 日是周一")
        XCTAssertEqual(june.weeks.first?.first?.id, "2026-06-01")
        XCTAssertEqual(june.weeks.first?.first?.isInMonth, true)
        XCTAssertEqual(june.weeks.last?.map(\.day), [29, 30, 1, 2, 3, 4, 5])

        let february = PhotoCalendar.month(year: 2027, month: 2, records: [], calendar: calendar, today: today)
        XCTAssertEqual(february.weeks.count, 4, "2027 年 2 月正好四周")
        XCTAssertTrue(february.weeks.joined().allSatisfy(\.isInMonth))
        XCTAssertFalse(february.weeks.joined().contains(where: \.isToday))
    }

    func testMonthOutOfRangeRollsOver() {
        let calendar = Self.shanghai
        let today = Self.date(calendar, 2026, 11, 23)
        let next = PhotoCalendar.month(year: 2026, month: 13, records: [], calendar: calendar, today: today)
        XCTAssertEqual(next.year, 2027)
        XCTAssertEqual(next.month, 1)
        XCTAssertEqual(next.weeks.joined().first(where: \.isInMonth)?.id, "2027-01-01")
        let previous = PhotoCalendar.month(year: 2026, month: 0, records: [], calendar: calendar, today: today)
        XCTAssertEqual(previous.year, 2025)
        XCTAssertEqual(previous.month, 12)
    }

    func testTodayCanBeALeadingDay() {
        let calendar = Self.shanghai
        let page = PhotoCalendar.month(year: 2026, month: 11, records: [], calendar: calendar, today: Self.date(calendar, 2026, 10, 28, hour: 23))
        XCTAssertEqual(page.weeks.joined().filter(\.isToday).map(\.id), ["2026-10-28"])
    }

    func testDaylightSavingDaysAreStillOneCellEach() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let today = Self.date(calendar, 2026, 11, 23)
        // 2026 年 3 月 8 日、11 月 1 日切换夏令时。
        for (month, length) in [(3, 31), (11, 30)] {
            let page = PhotoCalendar.month(year: 2026, month: month, records: [], calendar: calendar, today: today)
            let days = Array(page.weeks.joined())
            XCTAssertEqual(days.count, 42, "\(month)")
            XCTAssertEqual(Set(days.map(\.id)).count, days.count, "\(month)")
            XCTAssertEqual(days.filter(\.isInMonth).count, length, "\(month)")
            for (a, b) in zip(days, days.dropFirst()) {
                XCTAssertEqual(calendar.dateComponents([.day], from: a.date, to: b.date).day, 1, "\(a.id) → \(b.id)")
            }
        }
    }
}

// MARK: - 照片记录：新字段与旧数据兼容

final class LibraryV2RecordCodingTests: XCTestCase {
    private static let legacyID = "8D3F5D2A-1B2C-4D5E-8F90-123456789ABC"

    /// v0.1 照片库里的一条记录（PhotoLibrary 的写法：ISO 8601 日期，没有任何 v0.2 新字段）。
    private static let legacyJSON = #"""
    {
      "blotches" : [
        { "color" : "#DDEBE6", "kind" : "pale", "radius" : 0.12, "strength" : 0.6, "x" : 0.1, "y" : 0.9 }
      ],
      "body" : "instant",
      "caption" : "我可以见你吗？",
      "createdAt" : "2026-11-03T04:05:06Z",
      "desk" : { "layer" : "desktop", "rotation" : -2.5, "x" : 120, "y" : 340 },
      "developed" : true,
      "format" : "instantSquare",
      "frameOffsets" : [ ],
      "id" : "8D3F5D2A-1B2C-4D5E-8F90-123456789ABC",
      "negatives" : [ "8D3F5D2A-1B2C-4D5E-8F90-123456789ABC-0.jpg" ],
      "printFile" : "2026-11/Nocchi_20261103_120506_8d3f.jpg",
      "seed" : 77,
      "showsDate" : true,
      "source" : "selfie",
      "stockID" : "cream-600",
      "stockName" : "奶油 600",
      "strokes" : [
        { "color" : "#2B2A28", "points" : [ { "w" : 0.01, "x" : 0.1, "y" : 1.0 } ] }
      ]
    }
    """#

    /// 和 PhotoLibrary 一样：日期用 ISO 8601。
    private static func libraryDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private static func makeLibrary(_ name: String) throws -> PhotoLibrary {
        let root = temporaryDirectory(name)
        return try PhotoLibrary(root: root.appendingPathComponent("data"), printsRoot: root.appendingPathComponent("prints"))
    }

    func testLegacyRecordDecodesWithDefaults() throws {
        let record = try Self.libraryDecoder().decode(PhotoRecord.self, from: Data(Self.legacyJSON.utf8))
        XCTAssertEqual(record.id.uuidString, Self.legacyID)
        XCTAssertEqual(record.createdAt, Self.utc(2026, 11, 3, 4, 5, 6))
        XCTAssertEqual(record.caption, "我可以见你吗？")
        XCTAssertEqual(record.source, .selfie)
        XCTAssertEqual(record.body, .instant)
        XCTAssertEqual(record.format, .instantSquare)
        XCTAssertEqual(record.stockID, "cream-600")
        XCTAssertEqual(record.seed, 77)
        XCTAssertEqual(record.negatives.count, 1)
        XCTAssertEqual(record.desk?.layer, .desktop)
        XCTAssertEqual(record.blotches.first?.kind, .pale)
        XCTAssertEqual(record.strokes.first?.tool, .pen, "旧笔画按钢笔处理")
        XCTAssertEqual(record.strokes.first?.points.count, 1)

        // v0.2 新字段全部取默认值。
        XCTAssertNil(record.takenAt)
        XCTAssertNil(record.templateID)
        XCTAssertEqual(record.captionFont, .handwriting)
        XCTAssertNil(record.location)
        XCTAssertEqual(record.tags, [])
        XCTAssertEqual(record.stickers, [])
        XCTAssertTrue(record.showsTags)
        XCTAssertTrue(record.showsLocation)
        XCTAssertTrue(record.showsTagStickers)
        XCTAssertNil(record.editedAt)
        XCTAssertEqual(record.displayDate, record.createdAt)
        XCTAssertEqual(record.effectiveTemplateID, TemplateCatalog.defaultID(for: .instantSquare))
        XCTAssertNil(record.tagLine)
        XCTAssertNil(record.locationLine)
    }

    func testLegacyRecordLoadsThroughPhotoLibrary() throws {
        let library = try Self.makeLibrary("libraryv2-legacy")
        let url = library.recordsDirectory.appendingPathComponent(Self.legacyID + ".json")
        try Data(Self.legacyJSON.utf8).write(to: url)
        let id = try XCTUnwrap(UUID(uuidString: Self.legacyID))
        let loaded = try XCTUnwrap(library.record(id: id))
        XCTAssertEqual(loaded.caption, "我可以见你吗？")
        XCTAssertEqual(loaded.stickers, [])
        XCTAssertEqual(loaded.captionFont, .handwriting)
        XCTAssertEqual(library.loadAll().map(\.id), [id])
    }

    func testMinimalRecordJSONUsesDefaults() throws {
        let json = #"{"id":"8D3F5D2A-1B2C-4D5E-8F90-123456789ABC","createdAt":"2026-11-03T04:05:06Z"}"#
        let record = try Self.libraryDecoder().decode(PhotoRecord.self, from: Data(json.utf8))
        XCTAssertEqual(record.source, .screen)
        XCTAssertEqual(record.body, .instant)
        XCTAssertEqual(record.format, .instantSquare)
        XCTAssertEqual(record.stockID, FilmCatalog.defaultStock.id)
        XCTAssertEqual(record.negatives, [])
        XCTAssertTrue(record.showsDate)
        XCTAssertFalse(record.developed)
        XCTAssertEqual(record.captionFont, .handwriting)

        let booth = #"{"id":"8D3F5D2A-1B2C-4D5E-8F90-123456789ABC","createdAt":"2026-11-03T04:05:06Z","body":"photoBooth"}"#
        let boothRecord = try Self.libraryDecoder().decode(PhotoRecord.self, from: Data(booth.utf8))
        XCTAssertEqual(boothRecord.format, .boothStrip, "没有 format 时按机身推出来")
    }

    func testDecoratedRecordRoundTripsThroughPhotoLibrary() throws {
        var record = PhotoRecord(
            createdAt: Self.utc(2026, 11, 23, 10),
            source: .library,
            body: .instant,
            stock: FilmCatalog.defaultStock,
            seed: 4242,
            negatives: ["roundtrip-0.jpg"],
            strokes: [InkStroke(points: [InkPoint(x: 0.25, y: 1.5, w: 0.0125)], color: "#C4593B", tool: .grease)],
            caption: "海边的咖啡",
            takenAt: Self.utc(2026, 10, 1, 8, 30),
            templateID: "classic",
            captionFont: .typewriter,
            location: "上海",
            tags: ["阳光", "咖啡"],
            stickers: [
                StickerPlacement(kindID: "badge.sun", x: 0.8, y: 1.4, size: 0.18, rotation: -12, tint: "#D9A441", flipped: true),
                StickerPlacement(kindID: "label.text", x: 0.3, y: 1.45, size: 0.4, text: "NOCCHI")
            ],
            showsTags: false,
            showsLocation: false,
            showsTagStickers: false,
            editedAt: Self.utc(2026, 11, 24, 1, 2, 3)
        )
        record.format = .instantMini

        let library = try Self.makeLibrary("libraryv2-roundtrip")
        try library.save(record)
        let loaded = try XCTUnwrap(library.record(id: record.id))
        XCTAssertEqual(loaded, record)
        XCTAssertEqual(loaded.format, .instantMini)
        XCTAssertEqual(loaded.displayDate, Self.utc(2026, 10, 1, 8, 30))
        XCTAssertEqual(loaded.strokes.first?.tool, .grease)
        XCTAssertEqual(loaded.stickers.map(\.kindID), ["badge.sun", "label.text"])
        XCTAssertEqual(loaded.stickers.first?.flipped, true)
        XCTAssertEqual(loaded.stickers.last?.text, "NOCCHI")
        XCTAssertNil(loaded.tagLine, "关掉了印标签")
        XCTAssertNil(loaded.locationLine, "关掉了印地点")
    }

    func testInkStrokeWithoutToolIsPen() throws {
        let json = ##"{"points":[{"x":0.1,"y":1.2,"w":0.01}],"color":"#C4593B"}"##
        let stroke = try JSONDecoder().decode(InkStroke.self, from: Data(json.utf8))
        XCTAssertEqual(stroke.tool, .pen)
        XCTAssertEqual(stroke.color, "#C4593B")
        XCTAssertEqual(stroke.points, [InkPoint(x: 0.1, y: 1.2, w: 0.01)])
    }

    func testInkStrokeToolsRoundTrip() throws {
        for tool in InkTool.allCases {
            let stroke = InkStroke(points: [InkPoint(x: 0.5, y: 0.5, w: 0.02)], color: "#2B2A28", tool: tool)
            let data = try JSONEncoder().encode(stroke)
            let decoded = try JSONDecoder().decode(InkStroke.self, from: data)
            XCTAssertEqual(decoded, stroke, tool.rawValue)
        }
    }

    func testMinimalStickerPlacementJSON() throws {
        let sticker = try JSONDecoder().decode(StickerPlacement.self, from: Data(#"{"kindID":"badge.sun"}"#.utf8))
        XCTAssertEqual(sticker.kindID, "badge.sun")
        XCTAssertEqual(sticker.x, 0.5)
        XCTAssertEqual(sticker.y, 0.5)
        XCTAssertEqual(sticker.size, 0.2)
        XCTAssertEqual(sticker.rotation, 0)
        XCTAssertNil(sticker.tint)
        XCTAssertNil(sticker.text)
        XCTAssertFalse(sticker.flipped)
        XCTAssertThrowsError(try JSONDecoder().decode(StickerPlacement.self, from: Data("{}".utf8)), "没有 kindID 不能解码")
    }

    func testStickerPlacementRoundTrips() throws {
        let sticker = StickerPlacement(kindID: "stamp.postmark", x: 0.62, y: 1.31, size: 0.3, rotation: 8.5, tint: "#B23A2A", text: "NOCCHI · 2026.11.23")
        let data = try JSONEncoder().encode(sticker)
        XCTAssertEqual(try JSONDecoder().decode(StickerPlacement.self, from: data), sticker)
    }

    func testTagAndLocationLines() {
        XCTAssertEqual(PhotoRecord.normalizedTag("  ##阳光 "), "阳光")
        XCTAssertEqual(PhotoRecord.normalizedTag("＃咖啡"), "咖啡")
        XCTAssertEqual(PhotoRecord.normalizedTag("#"), "")
        var record = PhotoRecord(source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 1)
        XCTAssertNil(record.tagLine)
        XCTAssertNil(record.locationLine)
        record.tags = ["#阳光", " 咖啡 ", "#"]
        record.location = "  上海 "
        XCTAssertEqual(record.tagLine, "#阳光 #咖啡")
        XCTAssertEqual(record.locationLine, "上海")
        record.location = "   "
        XCTAssertNil(record.locationLine)
        record.showsTags = false
        XCTAssertNil(record.tagLine)
    }

    func testDisplayDatePrefersTakenAt() throws {
        // dateText 用当前时区，所以这里也用当前时区造时间。
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let created = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12)))
        var record = PhotoRecord(createdAt: created, source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 1)
        XCTAssertEqual(record.displayDate, created)
        XCTAssertEqual(record.dateText, "2026/11/23")
        record.takenAt = calendar.date(from: DateComponents(year: 1998, month: 7, day: 4, hour: 12))
        XCTAssertEqual(record.displayDate, record.takenAt)
        XCTAssertEqual(record.dateText, "1998/07/04")
    }
}

// MARK: - 相纸规格

final class LibraryV2FormatTests: XCTestCase {
    func testEveryFormatFitsItsPaper() {
        for format in FilmFormat.allCases {
            let layout = format.layout
            let paper = CGRect(origin: .zero, size: layout.paperSize)
            XCTAssertEqual(format.frameCount, layout.windows.count, "\(format)")
            XCTAssertTrue(paper.contains(layout.captionArea), "\(format) caption")
            for (i, window) in layout.windows.enumerated() {
                XCTAssertTrue(paper.contains(window), "\(format) window \(i)")
                XCTAssertFalse(window.intersects(layout.captionArea), "\(format) window \(i) overlaps caption")
                XCTAssertEqual(window.width / window.height, layout.windowAspect, accuracy: 0.01, "\(format) window \(i) aspect")
                for other in layout.windows[(i + 1)...] {
                    XCTAssertFalse(window.intersects(other), "\(format) windows overlap")
                }
            }
        }
    }

    func testBoothFormatsHaveFourWindows() {
        for format in FilmFormat.allCases {
            XCTAssertEqual(format.frameCount, format.isBooth ? 4 : 1, "\(format)")
            XCTAssertFalse(format.isBooth && format.isInstant, "\(format)")
        }
        XCTAssertEqual(PaperLayout.boothStrip.windows.count, 4)
        XCTAssertEqual(PaperLayout.boothGrid.windows.count, 4)
    }

    func testChoices() {
        XCTAssertEqual(FilmFormat.instantChoices, [.instantSquare, .instantMini, .instantWide, .landscape])
        XCTAssertEqual(FilmFormat.boothChoices, [.boothStrip, .boothGrid])
        XCTAssertEqual(Set(FilmFormat.instantChoices + FilmFormat.boothChoices), Set(FilmFormat.allCases))
        XCTAssertEqual(FilmFormat.instantChoices.count + FilmFormat.boothChoices.count, FilmFormat.allCases.count)
        XCTAssertTrue(FilmFormat.instantChoices.allSatisfy { !$0.isBooth })
        XCTAssertTrue(FilmFormat.boothChoices.allSatisfy(\.isBooth))
        XCTAssertEqual(FilmFormat.allCases.filter(\.isInstant), [.instantSquare, .instantMini, .instantWide])
    }

    func testShapesOfThePapers() {
        XCTAssertEqual(FilmFormat.instantSquare.layout.windowAspect, 1, accuracy: 1e-9)
        XCTAssertLessThan(FilmFormat.instantMini.layout.windowAspect, 1, "迷你即显是竖幅画面")
        XCTAssertGreaterThan(FilmFormat.instantWide.layout.windowAspect, 1, "宽幅即显是横幅画面")
        XCTAssertEqual(FilmFormat.landscape.layout.windowAspect, 1.5, accuracy: 0.01)
        XCTAssertEqual(FilmFormat.boothGrid.layout.windowAspect, 0.75, accuracy: 1e-9)
        XCTAssertLessThan(FilmFormat.instantMini.layout.aspect, 1)
        XCTAssertGreaterThan(FilmFormat.instantWide.layout.aspect, 1)
        // 即显相纸都有厚底边。
        for format in [FilmFormat.instantSquare, .instantMini, .instantWide] {
            let layout = format.layout
            let window = layout.windows[0]
            XCTAssertGreaterThan(layout.paperSize.height - window.maxY, window.minY * 2, "\(format)")
        }
    }

    func testNamesNotesAndSizes() {
        let names = FilmFormat.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        for format in FilmFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty, "\(format)")
            XCTAssertFalse(format.note.isEmpty, "\(format)")
            XCTAssertGreaterThan(format.defaultDisplayWidth, 0, "\(format)")
            XCTAssertGreaterThan(format.printPixelWidth, 0, "\(format)")
            XCTAssertEqual(format.id, format.rawValue)
            XCTAssertEqual(FilmFormat(rawValue: format.rawValue), format)
        }
        XCTAssertEqual(FilmFormat(rawValue: "boothStrip"), .boothStrip, "旧记录里的值不能变")
        XCTAssertEqual(FilmFormat(rawValue: "instantSquare"), .instantSquare)
        XCTAssertEqual(FilmFormat(rawValue: "landscape"), .landscape)
    }
}

// MARK: - 胶卷分组与推荐相纸

final class LibraryV2FamilyTests: XCTestCase {
    private static func stock(_ tags: [String]) -> FilmStock {
        FilmStock(id: "libv2-" + tags.joined(separator: "-"), name: "测试", tags: tags)
    }

    func testFamilyFromTags() {
        XCTAssertEqual(Self.stock(["instant", "warm", "default"]).family, .instant)
        XCTAssertEqual(Self.stock(["instant", "mini", "bright"]).family, .instant)
        XCTAssertEqual(Self.stock(["color", "warm", "portrait", "print"]).family, .color)
        XCTAssertEqual(Self.stock(["warm"]).family, .color)
        XCTAssertEqual(Self.stock([]).family, .color)
        XCTAssertEqual(Self.stock(["cine", "night"]).family, .cine)
        XCTAssertEqual(Self.stock(["cool", "night"]).family, .cine)
        XCTAssertEqual(Self.stock(["bw", "contrast"]).family, .bw)
        XCTAssertEqual(Self.stock(["bw", "night"]).family, .bw)
        XCTAssertEqual(Self.stock(["booth", "bw"]).family, .booth)
        XCTAssertEqual(Self.stock(["booth", "bright"]).family, .booth)
        XCTAssertEqual(Self.stock(["custom"]).family, .custom)
        XCTAssertEqual(FilmStock.custom(fromLUT: "mine.cube", title: "我的胶卷").family, .custom)

        var mono = Self.stock(["soft"])
        mono.tone.monochrome = true
        XCTAssertEqual(mono.family, .bw, "黑白配方没有 bw 标签也算黑白")
    }

    func testRecommendedFormatFromTags() {
        XCTAssertEqual(Self.stock(["booth", "bw"]).recommendedFormat, .boothStrip)
        XCTAssertEqual(Self.stock(["instant", "mini", "bright"]).recommendedFormat, .instantMini)
        XCTAssertEqual(Self.stock(["instant", "wide"]).recommendedFormat, .instantWide)
        XCTAssertEqual(Self.stock(["instant", "warm"]).recommendedFormat, .instantSquare)
        XCTAssertEqual(Self.stock(["color", "warm", "portrait", "print"]).recommendedFormat, .landscape)
        XCTAssertNil(Self.stock(["cine", "night"]).recommendedFormat)
        XCTAssertNil(Self.stock(["bw", "contrast"]).recommendedFormat)
        XCTAssertNil(Self.stock([]).recommendedFormat)
    }

    func testGroupedKeepsFamilyOrderAndStockOrder() {
        let stocks = [
            Self.stock(["bw"]), Self.stock(["instant"]), Self.stock(["warm"]),
            Self.stock(["booth"]), Self.stock(["instant", "mini"]), Self.stock(["night"])
        ]
        let groups = FilmCatalog.grouped(stocks)
        XCTAssertEqual(groups.map { $0.family }, [.instant, .color, .cine, .bw, .booth])
        XCTAssertEqual(groups.first?.stocks.map(\.id), [stocks[1].id, stocks[4].id])
        XCTAssertEqual(groups.reduce(0) { $0 + $1.stocks.count }, stocks.count)
        XCTAssertTrue(FilmCatalog.grouped([]).isEmpty)
    }

    func testBuiltInStocksEachLandInOneGroup() {
        let groups = FilmCatalog.grouped(FilmCatalog.builtIn)
        let ids = groups.flatMap { group in group.stocks.map(\.id) }
        XCTAssertEqual(ids.count, FilmCatalog.builtIn.count)
        XCTAssertEqual(Set(ids), Set(FilmCatalog.builtIn.map(\.id)))
        XCTAssertFalse(groups.contains { $0.family == .custom }, "内置胶卷不是自定义 LUT")
        XCTAssertEqual(FilmCatalog.defaultStock.family, .instant)
    }
}
