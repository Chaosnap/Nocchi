import CoreGraphics
import XCTest
@testable import NocchiKit

final class FilmCatalogTests: XCTestCase {
    func testBuiltInCatalogLoads() {
        let stocks = FilmCatalog.builtIn
        XCTAssertGreaterThanOrEqual(stocks.count, 12, "至少 12 卷内置胶卷")
        XCTAssertEqual(Set(stocks.map(\.id)).count, stocks.count, "id 不能重复")
        XCTAssertEqual(FilmCatalog.defaultStock.id, "cream-600")
    }

    func testEveryStockIsWellFormed() {
        for stock in FilmCatalog.builtIn {
            XCTAssertFalse(stock.name.isEmpty, stock.id)
            XCTAssertGreaterThan(stock.exposures, 0, stock.id)
            XCTAssertGreaterThan(stock.iso, 0, stock.id)
            XCTAssertEqual(stock.swatch.count, 3, "\(stock.id) 需要三种色卡颜色")
            for hex in stock.swatch {
                XCTAssertNotNil(RGB(hex: hex), "\(stock.id) swatch \(hex)")
            }
            XCTAssertNotNil(RGB(hex: stock.paper.color), stock.id)
            XCTAssertNotNil(RGB(hex: stock.paper.ink), stock.id)
            if let hex = stock.tone.shadowTint { XCTAssertNotNil(RGB(hex: hex), stock.id) }
            if let hex = stock.tone.highlightTint { XCTAssertNotNil(RGB(hex: hex), stock.id) }
            if let hex = stock.tone.monoTone { XCTAssertNotNil(RGB(hex: hex), stock.id) }
            let fx = stock.effects
            for v in [fx.grain, fx.halation, fx.bloom, fx.vignette, fx.lightLeak] {
                XCTAssertTrue((0...1).contains(v), "\(stock.id) effect out of range")
            }
        }
    }

    func testCatalogCoversRequiredMoods() {
        let tags = Set(FilmCatalog.builtIn.flatMap(\.tags))
        for required in ["warm", "cool", "pastel", "bw", "faded", "night", "contrast"] {
            XCTAssertTrue(tags.contains(required), "缺少风格：\(required)")
        }
    }

    func testBodiesReferenceExistingStocks() {
        let ids = Set(FilmCatalog.builtIn.map(\.id))
        for body in CameraBody.allCases {
            XCTAssertTrue(ids.contains(body.defaultStockID), "\(body) → \(body.defaultStockID)")
        }
    }

    func testLookupFallsBackToDefault() {
        XCTAssertEqual(FilmCatalog.stock(id: "does-not-exist").id, FilmCatalog.defaultStock.id)
        let custom = FilmStock.custom(fromLUT: "mine.cube", title: "我的胶卷")
        XCTAssertEqual(FilmCatalog.stock(id: custom.id, custom: [custom]).name, "我的胶卷")
    }

    func testStockRoundTripsThroughJSON() throws {
        let stock = FilmCatalog.builtIn[1]
        let data = try JSONEncoder().encode(stock)
        let decoded = try JSONDecoder().decode(FilmStock.self, from: data)
        XCTAssertEqual(decoded, stock)
    }

    func testMinimalStockJSON() throws {
        let json = #"{"version": 1, "stocks": [{"id": "x", "name": "最简"}]}"#.data(using: .utf8)!
        let stocks = try FilmCatalog.decode(json)
        XCTAssertEqual(stocks.first?.tone, .neutral)
        XCTAssertEqual(stocks.first?.effects, .clean)
        XCTAssertEqual(stocks.first?.paper, .classic)
    }
}

final class CropMathTests: XCTestCase {
    func testSquareCropOfLandscape() {
        let rect = CropMath.cropRect(imageSize: CGSize(width: 400, height: 200), aspect: 1)
        XCTAssertEqual(rect, CGRect(x: 100, y: 0, width: 200, height: 200))
    }

    func testFocusIsClampedInside() {
        let rect = CropMath.cropRect(imageSize: CGSize(width: 400, height: 200), aspect: 1, focus: CGPoint(x: 0.99, y: 0.5))
        XCTAssertEqual(rect.maxX, 400)
        XCTAssertEqual(rect.width, 200)
    }

    func testWideCropOfPortrait() {
        let rect = CropMath.cropRect(imageSize: CGSize(width: 300, height: 600), aspect: 1.5)
        XCTAssertEqual(rect.width, 300)
        XCTAssertEqual(rect.height, 200)
        XCTAssertEqual(rect.minY, 200)
    }
}

final class FilmProcessorTests: XCTestCase {
    private let processor = TestContext.processor

    func testOutputMatchesRequestedAspectAndSize() throws {
        let input = TestImages.gradient(width: 640, height: 400)
        let options = ProcessOptions(targetAspect: 1, maxLongEdge: 256, seed: 42)
        let out = try XCTUnwrap(processor.process(input, stock: FilmCatalog.defaultStock, options: options))
        XCTAssertEqual(out.width, out.height)
        XCTAssertLessThanOrEqual(out.width, 256)
        XCTAssertGreaterThanOrEqual(out.width, 255)
    }

    func testBoothStripWindowAspect() throws {
        let input = TestImages.gradient(width: 640, height: 480)
        let aspect = PaperLayout.boothStrip.windowAspect
        let out = try XCTUnwrap(processor.process(input, stock: FilmCatalog.stock(id: "booth-flash-400"), options: ProcessOptions(targetAspect: aspect, maxLongEdge: 300, seed: 3)))
        XCTAssertEqual(Double(out.width) / Double(out.height), Double(aspect), accuracy: 0.02)
    }

    func testSameSeedIsDeterministic() throws {
        let input = TestImages.gradient()
        let stock = FilmCatalog.stock(id: "midnight-1600")
        let options = ProcessOptions(targetAspect: 1, maxLongEdge: 160, seed: 99)
        let a = PixelBuffer(try XCTUnwrap(processor.process(input, stock: stock, options: options)))
        let b = PixelBuffer(try XCTUnwrap(processor.process(input, stock: stock, options: options)))
        XCTAssertLessThan(a.meanAbsoluteDifference(b), 0.5)
    }

    func testMonochromeStockProducesGrayImage() throws {
        let input = TestImages.gradient()
        let stock = FilmCatalog.stock(id: "old-news-100")
        XCTAssertTrue(stock.isMonochrome)
        let out = PixelBuffer(try XCTUnwrap(processor.process(input, stock: stock, options: ProcessOptions(maxLongEdge: 160, seed: 5))))
        XCTAssertLessThan(out.meanChannelSpread, 6, "黑白胶卷的输出应该接近灰度")
        XCTAssertGreaterThan(PixelBuffer(input).meanChannelSpread, 60)
    }

    func testEveryBuiltInStockRenders() {
        let input = TestImages.gradient(width: 160, height: 120)
        for stock in FilmCatalog.builtIn {
            let out = processor.process(input, stock: stock, options: ProcessOptions(targetAspect: 1, maxLongEdge: 96, seed: 7))
            XCTAssertNotNil(out, stock.id)
        }
    }

    func testFilmChangesTheImage() throws {
        let input = TestImages.gradient(width: 200, height: 200)
        let original = PixelBuffer(input)
        let out = PixelBuffer(try XCTUnwrap(processor.process(input, stock: FilmCatalog.stock(id: "sunset-200"), options: ProcessOptions(maxLongEdge: 400, seed: 1))))
        XCTAssertEqual(out.width, 200)
        XCTAssertGreaterThan(out.meanAbsoluteDifference(original), 3)
    }

    func testMirrorFlipsHorizontally() throws {
        let input = TestImages.gradient(width: 200, height: 100)
        let neutral = FilmStock(id: "neutral", name: "中性")
        let plain = PixelBuffer(try XCTUnwrap(processor.process(input, stock: neutral, options: ProcessOptions(maxLongEdge: 400))))
        let mirrored = PixelBuffer(try XCTUnwrap(processor.process(input, stock: neutral, options: ProcessOptions(maxLongEdge: 400, mirror: true))))
        // 原图左边偏红，镜像后右边偏红。
        XCTAssertGreaterThan(plain.rgb(5, 10).r, plain.rgb(194, 10).r)
        XCTAssertGreaterThan(mirrored.rgb(194, 10).r, mirrored.rgb(5, 10).r)
    }

    func testBlotchesAlterPixels() throws {
        let negative = TestImages.solid(0.5, 0.5, 0.5, width: 120, height: 120)
        let blotches = [Blotch(x: 0.5, y: 0.5, radius: 0.3, color: "#8A3A6A", strength: 0.8, kind: .stain)]
        let out = PixelBuffer(try XCTUnwrap(processor.applyingBlotches(blotches, to: negative)))
        let center = out.rgb(60, 60)
        XCTAssertLessThan(center.g, 120, "暗斑应该压暗中心")
        let corner = out.rgb(2, 2)
        XCTAssertLessThanOrEqual(abs(corner.g - 128), 3)
    }

    func testCustomLUTStockUsesFile() throws {
        let dir = temporaryDirectory("lut-stock")
        let inverted = """
        LUT_3D_SIZE 2
        1 1 1
        0 1 1
        1 0 1
        0 0 1
        1 1 0
        0 1 0
        1 0 0
        0 0 0
        """
        try inverted.write(to: dir.appendingPathComponent("invert.cube"), atomically: true, encoding: .utf8)
        let processor = FilmProcessor(context: TestContext.processor.context, lutDirectory: dir)
        let stock = FilmStock(id: "inv", name: "反相", lutFile: "invert.cube")
        let out = PixelBuffer(try XCTUnwrap(processor.process(TestImages.solid(1, 1, 1), stock: stock, options: ProcessOptions())))
        XCTAssertLessThan(out.rgb(10, 10).r, 20, "白色经过反相 LUT 应接近黑色")
    }
}
