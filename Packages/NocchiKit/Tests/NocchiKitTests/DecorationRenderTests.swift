import CoreGraphics
import XCTest
@testable import NocchiKit

/// 贴纸、相纸模板与分层合成。
final class StickerArtTests: XCTestCase {
    private static func alphaRange(_ image: CGImage) -> (opaque: Int, clear: Int) {
        let pixels = PixelBuffer(image)
        var opaque = 0
        var clear = 0
        var i = 3
        while i < pixels.bytes.count {
            if pixels.bytes[i] > 150 { opaque += 1 }
            if pixels.bytes[i] < 10 { clear += 1 }
            i += 4
        }
        return (opaque, clear)
    }

    func testCatalogIDsAreUniqueAndEveryCategoryIsPopulated() {
        let ids = StickerCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(ids.count, 40)
        for category in StickerCategory.allCases {
            XCTAssertFalse(StickerCatalog.kinds(in: category).isEmpty, category.rawValue)
        }
        for kind in StickerCatalog.all {
            XCTAssertFalse(kind.name.isEmpty, kind.id)
            XCTAssertGreaterThan(kind.aspect, 0, kind.id)
            XCTAssertEqual(StickerCatalog.kind(id: kind.id)?.id, kind.id)
        }
        XCTAssertNil(StickerCatalog.kind(id: "badge.does-not-exist"))
    }

    func testEveryStickerRendersWithShapeAndTransparency() throws {
        for kind in StickerCatalog.all {
            let image = try XCTUnwrap(StickerArt.image(kind, pixelWidth: 96, tint: nil, text: nil, seed: 7), kind.id)
            XCTAssertEqual(image.width, 96, kind.id)
            let alpha = Self.alphaRange(image)
            XCTAssertGreaterThan(alpha.opaque, 20, "\(kind.id) 应该画出东西")
            XCTAssertGreaterThan(alpha.clear, 20, "\(kind.id) 外面应该是透明的")
        }
    }

    func testTagMapping() {
        XCTAssertEqual(StickerCatalog.kindID(forTag: "阳光"), "badge.sun")
        XCTAssertEqual(StickerCatalog.kindID(forTag: "#咖啡"), "badge.coffee")
        XCTAssertEqual(StickerCatalog.kindID(forTag: "＃小狗"), "badge.dog")
        XCTAssertEqual(StickerCatalog.kindID(forTag: "Coffee"), "badge.coffee")
        XCTAssertEqual(StickerCatalog.kindID(forTag: "旅行"), "ephemera.luggage")
        XCTAssertNil(StickerCatalog.kindID(forTag: "随便"))
        XCTAssertNil(StickerCatalog.kindID(forTag: "#"))
        for tag in StickerCatalog.suggestedTags {
            XCTAssertNotNil(StickerCatalog.kindID(forTag: tag), tag)
        }
    }

    func testStableSeed() throws {
        let id = try XCTUnwrap(UUID(uuidString: "8D3F5D2A-1B2C-4D5E-8F90-123456789ABC"))
        let a = StickerPlacement(id: id, kindID: "badge.sun", x: 0.5, y: 0.5, size: 0.2)
        let b = StickerPlacement(id: id, kindID: "badge.moon", x: 0.1, y: 0.9, size: 0.3)
        XCTAssertEqual(a.stableSeed, b.stableSeed, "种子只取决于 UUID")
        let c = StickerPlacement(kindID: "badge.sun", x: 0.5, y: 0.5, size: 0.2)
        XCTAssertNotEqual(a.stableSeed, c.stableSeed)
    }

    func testFrameMath() {
        let placement = StickerPlacement(kindID: "tape.kraft", x: 0.5, y: 0.6, size: 0.36)
        let frame = StickerArt.frame(of: placement, paperWidth: 1000)
        XCTAssertEqual(frame.width, 360, accuracy: 0.001)
        XCTAssertEqual(frame.height, 100, accuracy: 0.001)
        XCTAssertEqual(frame.midX, 500, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 600, accuracy: 0.001)
    }

    func testInitialText() throws {
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone.current, year: 2026, month: 11, day: 23, hour: 12)))
        let postmark = try XCTUnwrap(StickerCatalog.kind(id: "stamp.postmark"))
        XCTAssertEqual(StickerCatalog.initialText(for: postmark, date: date), "NOCCHI · 2026.11.23")
        let label = try XCTUnwrap(StickerCatalog.kind(id: "label.embossed"))
        XCTAssertEqual(StickerCatalog.initialText(for: label, date: date), "NOCCHI")
        let sun = try XCTUnwrap(StickerCatalog.kind(id: "badge.sun"))
        XCTAssertNil(StickerCatalog.initialText(for: sun, date: date))
    }
}

final class TemplateRenderTests: XCTestCase {
    func testEveryFormatHasAtLeastThreeTemplates() {
        for format in FilmFormat.allCases {
            XCTAssertGreaterThanOrEqual(TemplateCatalog.templates(for: format).count, 3, "\(format)")
            XCTAssertEqual(TemplateCatalog.templates(for: format).first?.id, "classic")
        }
        let ids = TemplateCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryTemplateRendersAllLayersAtTheSameSize() throws {
        for template in TemplateCatalog.all {
            for format in template.formats {
                let layout = format.layout
                let images = layout.windows.map { _ in TestImages.solid(0.2, 0.5, 0.8, width: 60, height: 60) }
                let spec = PrintSpec(layout: layout, paper: .classic, images: images, caption: "测试 Test", dateText: "2026/11/23", widthPixels: 300, template: template, tagLine: "#阳光", locationLine: "上海", tagStickerIDs: ["badge.sun"], seed: 3)
                let full = try XCTUnwrap(PhotoComposer.render(spec), "\(template.id) \(format)")
                let base = try XCTUnwrap(PhotoComposer.renderBase(spec), "\(template.id) \(format)")
                let overlay = try XCTUnwrap(PhotoComposer.renderOverlay(spec), "\(template.id) \(format)")
                XCTAssertEqual(full.width, base.width)
                XCTAssertEqual(full.height, base.height)
                XCTAssertEqual(full.width, overlay.width)
                XCTAssertEqual(full.height, overlay.height)
            }
        }
    }

    func testHeartWindowStaysInsideItsRect() {
        let template = TemplateCatalog.template(id: "booth-heart")!
        let layout = PaperLayout.boothGrid
        for index in layout.windows.indices {
            let rect = layout.scaled(layout.windows[index], toWidth: 400)
            let path = PhotoComposer.windowPath(layout: layout, template: template, index: index, width: 400)
            XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingBoxOfPath), "window \(index)")
        }
    }

    func testRecordSpecUsesTemplatePaperAndDecorations() {
        var record = PhotoRecord(source: .screen, body: .instant, stock: FilmCatalog.defaultStock, seed: 9)
        record.templateID = "noir"
        record.tags = ["阳光", "咖啡", "小狗"]
        record.location = "上海"
        record.captionFont = .serif
        let spec = PrintSpec(record: record, stockPaper: .classic, images: [], widthPixels: 200)
        XCTAssertEqual(spec.template.id, "noir")
        XCTAssertEqual(spec.paper.color, "#1C1B1A")
        XCTAssertTrue(spec.paper.isDark)
        XCTAssertGreaterThan(ColorMath.luminance(spec.paper.inkRGB), 0.6, "深色相纸用浅色墨")
        XCTAssertEqual(spec.tagStickerIDs, ["badge.sun", "badge.coffee"])
        XCTAssertEqual(spec.locationLine, "上海")
        XCTAssertEqual(spec.captionFont, .serif)

        record.templateID = "booth-heart"
        let fallback = PrintSpec(record: record, stockPaper: .classic, images: [], widthPixels: 200)
        XCTAssertEqual(fallback.template.id, "classic", "不适用于这个画幅的模板回落到经典")
    }

    func testPaperIsTransparentOutsidePerforations() throws {
        let template = try XCTUnwrap(TemplateCatalog.template(id: "postage"))
        let spec = PrintSpec(layout: .instantSquare, paper: .classic, images: [], widthPixels: 400, template: template)
        let base = PixelBuffer(try XCTUnwrap(PhotoComposer.renderBase(spec)))
        let corner = (0 * base.width + 0) * 4 + 3
        XCTAssertLessThan(base.bytes[corner], 30, "邮票齿孔外面是透明的")
        let middle = (base.height / 2 * base.width + 8) * 4 + 3
        XCTAssertGreaterThan(base.bytes[middle], 200)
    }

    func testDateBackText() {
        XCTAssertEqual(TemplateArt.dateBackText("2026/11/23"), "'26 11 23")
        XCTAssertEqual(TemplateArt.dateBackText("bad"), "bad")
    }
}
