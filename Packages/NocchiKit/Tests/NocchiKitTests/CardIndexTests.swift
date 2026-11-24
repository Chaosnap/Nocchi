import Foundation
import XCTest
@testable import NocchiKit

/// 卡片盒的归档方式：首字母 / 年 / 月 / 日。
final class CardIndexTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func record(_ date: Date, caption: String? = nil) -> PhotoRecord {
        PhotoRecord(createdAt: date, source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 7, caption: caption)
    }

    func testLetterModeKeepsAllTwentySevenDividers() {
        let w = record(date(2026, 11, 24), caption: "我可以见你吗？")
        let a = record(date(2026, 11, 20), caption: "Apple")
        let layout = CardIndex.layout(for: [w, a], mode: .letter, language: .chinese, calendar: calendar)
        XCTAssertEqual(layout.tabs.count, 27)
        XCTAssertEqual(layout.tabs.first?.label, "A")
        XCTAssertEqual(layout.tabs.last?.label, "#")
        XCTAssertEqual(layout.count(forKey: "W"), 1)
        XCTAssertEqual(layout.count(forKey: "B"), 0)
        XCTAssertEqual(layout.slot(for: a), 0)
        XCTAssertEqual(layout.slot(for: w), 22)
        XCTAssertEqual(layout.label(for: w), "W")
    }

    func testYearMonthDayNewestFirst() {
        let records = [
            record(date(2025, 3, 2)),
            record(date(2026, 11, 24)),
            record(date(2026, 11, 24)),
            record(date(2026, 10, 31)),
        ]
        let years = CardIndex.layout(for: records, mode: .year, language: .chinese, calendar: calendar)
        XCTAssertEqual(years.tabs.map(\.label), ["2026", "2025"])
        XCTAssertEqual(years.tabs.map(\.count), [3, 1])
        XCTAssertEqual(years.tabs.map(\.slot), [0, 1])
        XCTAssertEqual(years.tabs.first?.title, "2026 年")

        let months = CardIndex.layout(for: records, mode: .month, language: .chinese, calendar: calendar)
        XCTAssertEqual(months.tabs.map(\.key), ["2026-11", "2026-10", "2025-03"])
        XCTAssertEqual(months.tabs.map(\.label), ["11月", "10月", "3月"])
        XCTAssertEqual(months.tabs.first?.title, "2026 年 11 月")

        let days = CardIndex.layout(for: records, mode: .day, language: .chinese, calendar: calendar)
        XCTAssertEqual(days.tabs.map(\.label), ["11/24", "10/31", "3/2"])
        XCTAssertEqual(days.tabs.first?.count, 2)
        XCTAssertEqual(days.tabs.first?.title, "2026 年 11 月 24 日")
        XCTAssertEqual(days.label(for: records[0]), "3/2")
        XCTAssertEqual(days.slot(for: records[0]), 2)
    }

    func testEnglishLabels() {
        let records = [record(date(2026, 11, 24))]
        let months = CardIndex.layout(for: records, mode: .month, language: .english, calendar: calendar)
        XCTAssertEqual(months.tabs.first?.label, "Nov")
        XCTAssertEqual(months.tabs.first?.title, "November 2026")
        let days = CardIndex.layout(for: records, mode: .day, language: .english, calendar: calendar)
        XCTAssertEqual(days.tabs.first?.label, "11/24")
        XCTAssertEqual(days.tabs.first?.title, "November 24, 2026")
    }

    func testOverflowGoesToTheLastDivider() {
        // 40 个不同的日子：前 26 个（最新的）各占一格，其余 14 天进「更早」。
        let records = (0..<40).map { record(date(2026, 1, 1).addingTimeInterval(Double($0) * 86_400)) }
        let days = CardIndex.layout(for: records, mode: .day, language: .chinese, calendar: calendar)
        XCTAssertEqual(days.tabs.count, CardIndex.slotCount)
        XCTAssertEqual(days.tabs.last?.key, CardIndex.olderKey)
        XCTAssertEqual(days.tabs.last?.label, "更早")
        XCTAssertEqual(days.tabs.last?.slot, 26)
        XCTAssertEqual(days.tabs.last?.count, 14)
        XCTAssertEqual(days.slot(for: records[0]), 26)
        XCTAssertEqual(days.slot(for: records[39]), 0)
        XCTAssertEqual(Set(days.tabs.map(\.slot)).count, CardIndex.slotCount)
    }

    func testTakenAtWins() {
        var moved = record(date(2026, 11, 24))
        moved.takenAt = date(2024, 6, 1)
        let years = CardIndex.layout(for: [moved], mode: .year, language: .chinese, calendar: calendar)
        XCTAssertEqual(years.tabs.map(\.label), ["2024"])
    }

    func testEmptyLibrary() {
        XCTAssertTrue(CardIndex.layout(for: [], mode: .day, language: .chinese, calendar: calendar).tabs.isEmpty)
        XCTAssertEqual(CardIndex.layout(for: [], mode: .letter, language: .chinese, calendar: calendar).tabs.count, 27)
    }

    func testSearchFindsEnglishMonthNames() {
        let november = record(date(2026, 11, 24), caption: "Latte")
        let march = record(date(2026, 3, 2), caption: "Tulips")
        XCTAssertEqual(PhotoSearch.englishMonth("nov"), 11)
        XCTAssertEqual(PhotoSearch.englishMonth("sept"), 9)
        XCTAssertNil(PhotoSearch.englishMonth("ju"))
        // 搜索用当前时区：中午的照片在任何时区都还是同一个月。
        XCTAssertTrue(PhotoSearch.matches(november, query: "nov"))
        XCTAssertFalse(PhotoSearch.matches(march, query: "nov"))
        XCTAssertTrue(PhotoSearch.matches(march, query: "March 2026"))
    }
}
