import CoreGraphics
import Foundation
import XCTest
@testable import NocchiKit

final class TextArtTests: XCTestCase {
    func testPlacementDecodesWithDefaults() throws {
        let json = #"{"text": "你好 Nocchi"}"#.data(using: .utf8)!
        let placement = try JSONDecoder().decode(TextPlacement.self, from: json)
        XCTAssertEqual(placement.text, "你好 Nocchi")
        XCTAssertEqual(placement.style, .plain)
        XCTAssertEqual(placement.alignment, 0)
        XCTAssertEqual(placement.x, 0.5, accuracy: 0.0001)
    }

    func testRecordWithoutTextsStillDecodes() throws {
        var record = PhotoRecord(source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 1)
        record.texts = [TextPlacement(text: "海边", x: 0.3, y: 0.4)]
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(PhotoRecord.self, from: data)
        XCTAssertEqual(decoded.texts, record.texts)
        // 旧照片库：去掉 texts 字段。
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "texts")
        let old = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try JSONDecoder().decode(PhotoRecord.self, from: old).texts, [])
    }

    func testEveryStyleRendersVisibleInk() throws {
        for style in TextPlacement.Style.allCases {
            let text = TextPlacement(text: "Nocchi\n冲印店", fontFamily: "Baskerville", size: 0.1, color: "#B23A2A", style: style)
            let image = try XCTUnwrap(TextArt.image(text, paperWidth: 600), "\(style)")
            let pixels = PixelBuffer(image)
            var opaque = 0
            var index = 3
            while index < pixels.bytes.count {
                if pixels.bytes[index] > 150 { opaque += 1 }
                index += 4
            }
            XCTAssertGreaterThan(opaque, 200, "\(style) should draw ink")
            let frame = TextArt.frame(of: text, paperWidth: 600)
            XCTAssertEqual(Double(frame.width), Double(image.width), accuracy: 2, "\(style) frame matches the rendered image")
        }
    }

    func testOutlineAddsAWhiteEdge() throws {
        let plain = TextPlacement(text: "W", fontFamily: "Baskerville", size: 0.2, color: "#2B2A28", style: .plain)
        var outline = plain
        outline.style = .outline
        let plainImage = PixelBuffer(try XCTUnwrap(TextArt.image(plain, paperWidth: 400)))
        let outlineImage = PixelBuffer(try XCTUnwrap(TextArt.image(outline, paperWidth: 400)))
        func whiteCount(_ buffer: PixelBuffer) -> Int {
            var count = 0
            var i = 0
            while i < buffer.bytes.count {
                if buffer.bytes[i + 3] > 200, buffer.bytes[i] > 230, buffer.bytes[i + 1] > 230, buffer.bytes[i + 2] > 230 { count += 1 }
                i += 4
            }
            return count
        }
        XCTAssertEqual(whiteCount(plainImage), 0)
        XCTAssertGreaterThan(whiteCount(outlineImage), 50)
    }

    func testAlignmentAndRotationDoNotCrash() {
        for alignment in [-1, 0, 1] {
            for rotation in [-30.0, 0, 45] {
                let text = TextPlacement(text: "一\n二三四五", size: 0.08, rotation: rotation, alignment: alignment, bold: true, italic: true, tracking: 0.1)
                XCTAssertNotNil(TextArt.image(text, paperWidth: 300))
            }
        }
        XCTAssertNil(TextArt.image(TextPlacement(text: "   "), paperWidth: 300))
    }

    func testComposerDrawsTextsIntoTheOverlay() throws {
        let layout = PaperLayout.instantSquare
        let base = PrintSpec(layout: layout, paper: .classic, images: [], widthPixels: 300)
        var withText = base
        withText.texts = [TextPlacement(text: "HELLO", size: 0.12, color: "#000000", x: 0.5, y: 0.3, style: .label)]
        let a = PixelBuffer(try XCTUnwrap(PhotoComposer.renderOverlay(base)))
        let b = PixelBuffer(try XCTUnwrap(PhotoComposer.renderOverlay(withText)))
        XCTAssertNotEqual(a.bytes, b.bytes)
        let c = PixelBuffer(try XCTUnwrap(PhotoComposer.renderOverlay(withText, includeStickers: false)))
        XCTAssertEqual(a.bytes, c.bytes, "texts belong to the sticker layer")
    }

    func testImportingAFontRegistersItsFamily() throws {
        let fonts = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental")
        let candidates = (try? FileManager.default.contentsOfDirectory(at: fonts, includingPropertiesForKeys: nil)) ?? []
        guard let file = candidates.first(where: { $0.pathExtension.lowercased() == "ttf" }) else {
            throw XCTSkip("no .ttf in Supplemental on this runner")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nocchi-fonts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomFontStore(directory: directory)
        let families = try store.importFont(from: file)
        XCTAssertFalse(families.isEmpty)
        XCTAssertEqual(store.fontFiles.count, 1)
        XCTAssertTrue(families.allSatisfy { FontBook.isInstalled($0) })
        XCTAssertThrowsError(try store.importFont(from: URL(fileURLWithPath: "/tmp/not-a-font.txt")))
        store.remove(family: families[0])
        XCTAssertTrue(store.fontFiles.isEmpty)
    }
}
