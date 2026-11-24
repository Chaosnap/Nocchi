import CoreGraphics
import XCTest
@testable import NocchiKit

/// 设置里换成片位置：已有的成片搬过去，记录里的相对路径照样找得到。
final class PrintsRelocationTests: XCTestCase {
    private func makeLibrary(_ name: String) throws -> (PhotoLibrary, URL) {
        let base = temporaryDirectory("relocate-\(name)")
        let library = try PhotoLibrary(root: base.appendingPathComponent("data"), printsRoot: base.appendingPathComponent("prints"))
        return (library, base)
    }

    private func printed(_ library: PhotoLibrary, seconds: TimeInterval) throws -> PhotoRecord {
        var record = PhotoRecord(createdAt: Date(timeIntervalSince1970: seconds), source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 5)
        record.printFile = try library.writePrint(TestImages.solid(0.8, 0.6, 0.4, width: 32, height: 40), for: record)
        try library.save(record)
        return record
    }

    func testMovesEveryPrintAndKeepsRecordsWorking() throws {
        let (library, base) = try makeLibrary("move")
        let november = try printed(library, seconds: 1_795_500_000)
        let october = try printed(library, seconds: 1_793_000_000)
        let oldRoot = library.printsRoot
        XCTAssertEqual(library.printFileCount(), 2)

        let newRoot = base.appendingPathComponent("External/My Prints")
        let result = try library.relocatePrints(to: newRoot)

        XCTAssertEqual(result.moved, 2)
        XCTAssertTrue(result.skipped.isEmpty)
        XCTAssertEqual(library.printsRoot.standardizedFileURL.path, newRoot.standardizedFileURL.path)
        for record in [november, october] {
            let relative = try XCTUnwrap(record.printFile)
            XCTAssertTrue(FileManager.default.fileExists(atPath: library.printURL(relative).path), relative)
            XCTAssertFalse(FileManager.default.fileExists(atPath: oldRoot.appendingPathComponent(relative).path), relative)
            XCTAssertNotNil(ImageIOKit.load(library.printURL(relative)))
        }
        // 搬空的月份文件夹删掉了，原来的成片文件夹本身还在。
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: oldRoot.path).filter { !$0.hasPrefix(".") }
        XCTAssertTrue(leftovers.isEmpty, "\(leftovers)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldRoot.path))

        // 之后冲印的成片直接写到新位置。
        let later = try printed(library, seconds: 1_795_600_000)
        let laterURL = library.printURL(try XCTUnwrap(later.printFile))
        XCTAssertTrue(laterURL.standardizedFileURL.path.hasPrefix(newRoot.standardizedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: laterURL.path))
    }

    func testSameFolderIsANoOp() throws {
        let (library, _) = try makeLibrary("same")
        _ = try printed(library, seconds: 1_795_500_000)
        let result = try library.relocatePrints(to: library.printsRoot)
        XCTAssertEqual(result, PhotoLibrary.RelocationResult(moved: 0, skipped: []))
        XCTAssertEqual(library.printFileCount(), 1)
    }

    func testRefusesAFolderInsideTheCurrentOne() throws {
        let (library, _) = try makeLibrary("nested")
        let inside = library.printsRoot.appendingPathComponent("Sub")
        XCTAssertThrowsError(try library.relocatePrints(to: inside)) { error in
            XCTAssertEqual(error as? PhotoLibrary.RelocationError, .nested)
        }
        let outside = library.printsRoot.deletingLastPathComponent()
        XCTAssertThrowsError(try library.relocatePrints(to: outside)) { error in
            XCTAssertEqual(error as? PhotoLibrary.RelocationError, .nested)
        }
    }

    func testRefusesAFile() throws {
        let (library, base) = try makeLibrary("file")
        let file = base.appendingPathComponent("not-a-folder.txt")
        try Data("x".utf8).write(to: file)
        XCTAssertThrowsError(try library.relocatePrints(to: file)) { error in
            XCTAssertEqual(error as? PhotoLibrary.RelocationError, .notAFolder)
        }
    }

    func testNeverOverwritesAnExistingFile() throws {
        let (library, base) = try makeLibrary("clash")
        let record = try printed(library, seconds: 1_795_500_000)
        let relative = try XCTUnwrap(record.printFile)
        let oldURL = library.printURL(relative)
        let newRoot = base.appendingPathComponent("elsewhere")
        let clash = newRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: clash.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("someone else's file".utf8).write(to: clash)

        let result = try library.relocatePrints(to: newRoot)
        XCTAssertEqual(result.moved, 0)
        XCTAssertEqual(result.skipped, [relative])
        XCTAssertEqual(try String(contentsOf: clash, encoding: .utf8), "someone else's file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path), "原文件留在原处")
    }
}
