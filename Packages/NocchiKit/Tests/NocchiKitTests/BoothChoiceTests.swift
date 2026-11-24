import CoreGraphics
import XCTest
@testable import NocchiKit

/// 大头贴机「选相框」：相框顺序、黑白 / 彩色选卷、模板预览。
final class BoothChoiceTests: XCTestCase {
    func testBoothTemplatesPutThemesFirstAndKeepEveryUsableTemplate() {
        for format in FilmFormat.boothChoices {
            let list = TemplateCatalog.boothTemplates(for: format)
            XCTAssertEqual(list.first?.id, TemplateCatalog.defaultBoothID, "\(format)")
            XCTAssertTrue(list.prefix(6).allSatisfy { $0.id.hasPrefix("booth-") }, "\(format)")
            XCTAssertEqual(list.count, TemplateCatalog.templates(for: format).count, "\(format)")
            XCTAssertEqual(Set(list.map(\.id)), Set(TemplateCatalog.templates(for: format).map(\.id)), "\(format)")
            XCTAssertTrue(list.allSatisfy { $0.formats.contains(format) }, "\(format)")
        }
        XCTAssertNotNil(TemplateCatalog.template(id: TemplateCatalog.defaultBoothID))
    }

    func testBoothStocksExistAndMatchTheToggle() {
        let flash = FilmCatalog.stock(id: FilmCatalog.boothColorID)
        let silver = FilmCatalog.stock(id: FilmCatalog.boothMonoID)
        XCTAssertEqual(flash.id, FilmCatalog.boothColorID)
        XCTAssertEqual(silver.id, FilmCatalog.boothMonoID)
        XCTAssertFalse(flash.isMonochrome)
        XCTAssertTrue(silver.isMonochrome)
        XCTAssertEqual(CameraBody.photoBooth.defaultStockID, FilmCatalog.boothColorID)
    }

    func testBoothStockChoiceRespectsTheLoadedRoll() throws {
        let standard = FilmCatalog.defaultStock
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: false, loaded: standard), FilmCatalog.boothColorID)
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: true, loaded: standard), FilmCatalog.boothMonoID)

        let grit = FilmCatalog.stock(id: "grit-400")
        XCTAssertEqual(grit.id, "grit-400")
        XCTAssertTrue(grit.isMonochrome)
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: true, loaded: grit), "grit-400")
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: false, loaded: grit), FilmCatalog.boothColorID)

        let gold = FilmCatalog.stock(id: "gold-200")
        XCTAssertEqual(gold.id, "gold-200")
        XCTAssertFalse(gold.isMonochrome)
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: false, loaded: gold), "gold-200")
        XCTAssertEqual(FilmCatalog.boothStockID(monochrome: true, loaded: gold), FilmCatalog.boothMonoID)
    }

    func testPlaceholderKeepsTheWindowAspectAndShowsAFigure() throws {
        let image = try XCTUnwrap(TemplatePreview.placeholder(aspect: 4.0 / 3.0, pixelWidth: 120, monochrome: false, index: 0))
        XCTAssertEqual(image.width, 120)
        XCTAssertEqual(image.height, 90)
        let pixels = PixelBuffer(image)
        // 左上角被暖光照亮，剪影（下方中间）更暗。
        let corner = pixels.rgb(8, 8)
        let figure = pixels.rgb(57, 80)
        XCTAssertGreaterThan(corner.r + corner.g + corner.b, figure.r + figure.g + figure.b + 30)
        // 彩色是暖灰（红 > 蓝），黑白是中性灰。
        XCTAssertGreaterThan(corner.r, corner.b)
        let mono = PixelBuffer(try XCTUnwrap(TemplatePreview.placeholder(aspect: 0.75, pixelWidth: 90, monochrome: true, index: 2)))
        XCTAssertEqual(mono.height, 120)
        XCTAssertLessThan(mono.meanChannelSpread, 3)
    }

    func testPreviewRendersEveryBoothTemplateInBothLayouts() throws {
        for monochrome in [false, true] {
            let stock = FilmCatalog.stock(id: monochrome ? FilmCatalog.boothMonoID : FilmCatalog.boothColorID)
            for format in FilmFormat.boothChoices {
                for template in TemplateCatalog.boothTemplates(for: format) {
                    let image = try XCTUnwrap(
                        TemplatePreview.render(template: template, format: format, stock: stock, caption: "我可以见你吗？", widthPixels: 160),
                        "\(template.id) \(format)"
                    )
                    XCTAssertEqual(image.width, 160, "\(template.id) \(format)")
                    XCTAssertEqual(image.height, Int((160 / format.layout.aspect).rounded()), "\(template.id) \(format)")
                }
            }
        }
    }

    func testValentineFrameUsesTheBlenderLayers() throws {
        for layout in [PaperLayout.boothStrip, .boothGrid] {
            let size = layout.size(forWidth: 400)
            let base = try XCTUnwrap(FrameLayers.valentine(.base, layout: layout, size: size), "\(layout)")
            let overlay = try XCTUnwrap(FrameLayers.valentine(.overlay, layout: layout, size: size), "\(layout)")
            XCTAssertEqual(Double(base.width) / Double(base.height), Double(layout.aspect), accuracy: 0.02)
            XCTAssertEqual(Double(overlay.width) / Double(overlay.height), Double(layout.aspect), accuracy: 0.02)
            XCTAssertNotEqual(overlay.alphaInfo, .none, "the overlay must be transparent outside its parts")
        }
        XCTAssertNil(FrameLayers.valentine(.base, layout: .instantSquare, size: CGSize(width: 400, height: 486)))
        // 合成的成片里，卡纸是雾玫瑰色、纸边是奶油色的蕾丝。
        let stock = FilmCatalog.stock(id: FilmCatalog.boothColorID)
        let heart = try XCTUnwrap(TemplateCatalog.template(id: "booth-heart"))
        let image = try XCTUnwrap(TemplatePreview.render(template: heart, format: .boothStrip, stock: stock, widthPixels: 520))
        let pixels = PixelBuffer(image)
        let card = pixels.rgb(Int(Double(pixels.width) * 0.5), Int(Double(pixels.height) * 0.235))
        XCTAssertGreaterThan(card.r, card.b + 15, "rose card between the first two windows: \(card)")
    }

    func testPreviewFallsBackWhenTheTemplateDoesNotFitTheFormat() throws {
        // 邮票只给即显相纸用：放到四格条上时按默认模板合成，不会失败。
        let postage = try XCTUnwrap(TemplateCatalog.template(id: "postage"))
        XCTAssertFalse(postage.formats.contains(.boothStrip))
        let stock = FilmCatalog.stock(id: FilmCatalog.boothColorID)
        let day = Date(timeIntervalSince1970: 1_795_000_000)
        let fallback = try XCTUnwrap(TemplatePreview.render(template: postage, format: .boothStrip, stock: stock, date: day, widthPixels: 120))
        let classic = try XCTUnwrap(TemplatePreview.render(template: TemplateCatalog.classic, format: .boothStrip, stock: stock, date: day, widthPixels: 120))
        XCTAssertEqual(PixelBuffer(fallback).meanAbsoluteDifference(PixelBuffer(classic)), 0, accuracy: 0.5)
    }
}
