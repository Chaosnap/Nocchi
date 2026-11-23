import CoreGraphics
import XCTest
@testable import NocchiKit

final class PhotoLibraryTests: XCTestCase {
    private func makeLibrary(_ name: String) throws -> PhotoLibrary {
        let root = temporaryDirectory(name)
        return try PhotoLibrary(root: root.appendingPathComponent("data"), printsRoot: root.appendingPathComponent("prints"))
    }

    func testSaveAndLoadRoundTrip() throws {
        let library = try makeLibrary("roundtrip")
        var record = PhotoRecord(source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 77)
        record.caption = "MAY I MEET YOU"
        record.strokes = [InkStroke(points: [InkPoint(x: 0.1, y: 1.0, w: 0.01), InkPoint(x: 0.2, y: 1.02, w: 0.012)], color: "#2B2A28")]
        record.blotches = [Blotch.make(seed: 77, index: 0)]
        record.desk = DeskPlacement(x: 120, y: 340, rotation: -2.5, layer: .desktop)
        let name = try library.writeNegative(TestImages.gradient(width: 64, height: 64), recordID: record.id, index: 0)
        record.negatives = [name]
        try library.save(record)

        let loaded = try XCTUnwrap(library.record(id: record.id))
        XCTAssertEqual(loaded.caption, "MAY I MEET YOU")
        XCTAssertEqual(loaded.strokes, record.strokes)
        XCTAssertEqual(loaded.blotches, record.blotches)
        XCTAssertEqual(loaded.desk, record.desk)
        XCTAssertEqual(loaded.seed, 77)
        XCTAssertEqual(loaded.format, .instantSquare)
        XCTAssertEqual(library.loadNegatives(of: loaded).count, 1)
        XCTAssertEqual(library.loadAll().count, 1)
    }

    func testLoadAllSortsNewestFirst() throws {
        let library = try makeLibrary("sorting")
        let old = PhotoRecord(createdAt: Date(timeIntervalSince1970: 1_000), source: .selfie, body: .instant, stock: FilmCatalog.defaultStock, seed: 1)
        let new = PhotoRecord(createdAt: Date(timeIntervalSince1970: 9_000), source: .selfie, body: .instant, stock: FilmCatalog.defaultStock, seed: 2)
        try library.save(old)
        try library.save(new)
        XCTAssertEqual(library.loadAll().map(\.id), [new.id, old.id])
    }

    func testWritePrintUsesMonthFolder() throws {
        let library = try makeLibrary("prints")
        var record = PhotoRecord(source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 3)
        let relative = try library.writePrint(TestImages.solid(1, 1, 1), for: record)
        XCTAssertTrue(relative.hasPrefix(PhotoLibrary.monthKeyFormatter.string(from: record.createdAt) + "/Nocchi_"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.printURL(relative).path))
        record.printFile = relative
        let again = try library.writePrint(TestImages.solid(0, 0, 0), for: record)
        XCTAssertEqual(again, relative, "已有成片时覆盖同一个文件")
    }

    func testRemoveRecordDeletesNegatives() throws {
        let library = try makeLibrary("remove")
        var record = PhotoRecord(source: .booth, body: .photoBooth, stock: FilmCatalog.defaultStock, seed: 4)
        record.negatives = try (0..<4).map { try library.writeNegative(TestImages.solid(0.2, 0.4, 0.6), recordID: record.id, index: $0) }
        try library.save(record)
        library.removeRecord(record, deletePrint: true)
        XCTAssertNil(library.record(id: record.id))
        for name in record.negatives {
            XCTAssertFalse(FileManager.default.fileExists(atPath: library.negativeURL(name).path))
        }
    }

    func testImportLUTValidatesFile() throws {
        let library = try makeLibrary("import")
        let dir = temporaryDirectory("import-src")
        let bad = dir.appendingPathComponent("bad.cube")
        try "LUT_3D_SIZE 2\n0 0 0\n".write(to: bad, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try library.importLUT(from: bad))

        let good = dir.appendingPathComponent("good.cube")
        try LUTBaker.bake(ToneRecipe(saturation: 0.5), dimension: 4).cubeText(title: "Good").write(to: good, atomically: true, encoding: .utf8)
        let result = try library.importLUT(from: good)
        XCTAssertTrue(result.fileName.hasSuffix(".cube"))
        XCTAssertEqual(result.lut.title, "Good")
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.lutsDirectory.appendingPathComponent(result.fileName).path))
    }

    func testGroupedByMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let stock = FilmCatalog.defaultStock
        let nov = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        let oct = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        let records = [
            PhotoRecord(createdAt: oct, source: .screen, body: .instant, stock: stock, seed: 1),
            PhotoRecord(createdAt: nov, source: .screen, body: .instant, stock: stock, seed: 2),
            PhotoRecord(createdAt: nov.addingTimeInterval(3600), source: .screen, body: .instant, stock: stock, seed: 3)
        ]
        let groups = PhotoLibrary.groupedByMonth(records, calendar: calendar)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.records.count, 2)
        XCTAssertTrue(groups.first?.title.contains("11 月") ?? false)
    }

    func testFrameOffsetsAndTiltAreDeterministic() {
        let a = PhotoRecord.makeFrameOffsets(count: 4, seed: 9, amount: 0.015)
        XCTAssertEqual(a, PhotoRecord.makeFrameOffsets(count: 4, seed: 9, amount: 0.015))
        XCTAssertTrue(a.allSatisfy { abs($0.dx) <= 0.015 && abs($0.dy) <= 0.015 })
        XCTAssertEqual(PhotoRecord.randomTilt(seed: 5), PhotoRecord.randomTilt(seed: 5))
        XCTAssertLessThanOrEqual(abs(PhotoRecord.randomTilt(seed: 5)), 4.5)
    }
}

final class PhotoComposerTests: XCTestCase {
    func testRenderSizeAndPaperColor() throws {
        let layout = PaperLayout.instantSquare
        let spec = PrintSpec(
            layout: layout,
            paper: PaperStyle(color: "#FF0000", ink: "#000000"),
            images: [TestImages.solid(0, 0, 1, width: 100, height: 100)],
            caption: "你好 Nocchi",
            dateText: "2026/11/23",
            widthPixels: 880
        )
        let image = try XCTUnwrap(PhotoComposer.render(spec))
        XCTAssertEqual(image.width, 880)
        XCTAssertEqual(image.height, 1070)
        let pixels = PixelBuffer(image)
        // 左上白边是相纸颜色（红），窗口中心是底片（蓝）。
        let border = pixels.rgb(20, 20)
        XCTAssertGreaterThan(border.r, 240)
        XCTAssertLessThan(border.b, 15)
        let center = pixels.rgb(440, 450)
        XCTAssertGreaterThan(center.b, 240)
        XCTAssertLessThan(center.r, 15)
    }

    func testStrokesAreDrawn() throws {
        let layout = PaperLayout.instantSquare
        let y = Double(layout.captionArea.midY / layout.paperSize.width)
        let stroke = InkStroke(points: [InkPoint(x: 0.2, y: y, w: 0.02), InkPoint(x: 0.8, y: y, w: 0.02)], color: "#000000")
        let spec = PrintSpec(layout: layout, paper: .classic, images: [], strokes: [stroke], widthPixels: 400)
        let pixels = PixelBuffer(try XCTUnwrap(PhotoComposer.render(spec)))
        let mark = pixels.rgb(200, Int(y * 400))
        XCTAssertLessThan(mark.r, 40, "笔画经过的地方应该是黑色")
    }

    func testBoothStripRendersFourWindows() throws {
        let images = (0..<4).map { _ in TestImages.solid(0, 1, 0, width: 80, height: 60) }
        let spec = PrintSpec(layout: .boothStrip, paper: .classic, images: images, frameOffsets: PhotoRecord.makeFrameOffsets(count: 4, seed: 1, amount: 0.01), widthPixels: 520)
        let image = try XCTUnwrap(PhotoComposer.render(spec))
        XCTAssertEqual(image.height, 1600)
        let pixels = PixelBuffer(image)
        for window in PaperLayout.boothStrip.windows {
            let rect = PaperLayout.boothStrip.scaled(window, toWidth: 520)
            let c = pixels.rgb(Int(rect.midX), Int(rect.midY))
            XCTAssertGreaterThan(c.g, 230)
        }
    }

    func testAspectFill() {
        let rect = PhotoComposer.aspectFill(CGSize(width: 200, height: 100), into: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(rect.height, 100)
        XCTAssertEqual(rect.width, 200)
        XCTAssertEqual(rect.midX, 50)
    }
}
