import XCTest
@testable import NocchiKit

/// v0.2 调色引擎（曲线、HSL、肤色保护、高光软肩、雾化）与 26 卷内置胶卷。
final class FilmLooksTests: XCTestCase {
    private static let newStockIDs = [
        "portrait-400", "gold-200", "vivid-100", "tungsten-800", "mint-400", "evergreen-400",
        "everyday-200", "crisp-800", "grit-400", "fine-100", "booth-silver-400"
    ]

    func testCatalogHasAllStocksAndDefaultFirst() {
        let ids = FilmCatalog.builtIn.map(\.id)
        XCTAssertEqual(ids.count, 26)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, "cream-600")
        XCTAssertEqual(FilmCatalog.defaultStock.id, "cream-600")
        for id in Self.newStockIDs {
            XCTAssertTrue(ids.contains(id), id)
        }
    }

    func testEveryStockHasNameSwatchesAndSummary() {
        for stock in FilmCatalog.builtIn {
            XCTAssertFalse(stock.name.isEmpty, stock.id)
            XCTAssertFalse(stock.englishName.isEmpty, stock.id)
            XCTAssertFalse(stock.summary.isEmpty, stock.id)
            XCTAssertEqual(stock.swatch.compactMap { RGB(hex: $0) }.count, 3, stock.id)
            XCTAssertGreaterThan(stock.exposures, 0, stock.id)
        }
    }

    func testEveryStockBakesAWellFormedCube() {
        for stock in FilmCatalog.builtIn {
            let cube = LUTBaker.bake(stock.tone, dimension: 9)
            XCTAssertTrue(cube.isWellFormed, stock.id)
        }
    }

    func testFamiliesAreAllRepresented() {
        let families = Set(FilmCatalog.builtIn.map(\.family))
        XCTAssertEqual(families, [.instant, .color, .cine, .bw, .booth])
        XCTAssertEqual(FilmCatalog.stock(id: "booth-silver-400").family, .booth)
        XCTAssertTrue(FilmCatalog.stock(id: "booth-silver-400").isMonochrome)
        XCTAssertEqual(FilmCatalog.stock(id: "crisp-800").recommendedFormat, .instantMini)
        XCTAssertEqual(FilmCatalog.stock(id: "tungsten-800").family, .cine)
        XCTAssertEqual(FilmCatalog.stock(id: "portrait-400").recommendedFormat, .landscape)
    }

    func testMonochromeStocksWithoutToningAreNeutral() {
        for stock in FilmCatalog.builtIn where stock.isMonochrome && stock.tone.monoToneAmount == 0 {
            for probe in [RGB(0.9, 0.2, 0.4), RGB(0.1, 0.7, 0.3), RGB(0.5, 0.5, 0.9)] {
                let out = stock.tone.apply(to: probe)
                XCTAssertEqual(out.x, out.y, accuracy: 1e-5, stock.id)
                XCTAssertEqual(out.y, out.z, accuracy: 1e-5, stock.id)
            }
        }
    }

    // MARK: - 曲线

    func testDiagonalCurveIsIdentity() {
        let curve = MonotoneCurve(points: [CurvePoint(0, 0), CurvePoint(0.5, 0.5), CurvePoint(1, 1)])
        XCTAssertTrue(curve.isIdentity)
        for x in stride(from: Float(0), through: 1, by: 0.05) {
            XCTAssertEqual(curve.evaluate(x), x, accuracy: 1e-5)
        }
        let recipe = ToneRecipe(curves: ToneCurves(master: [CurvePoint(0, 0), CurvePoint(1, 1)]))
        let out = recipe.apply(to: RGB(0.2, 0.5, 0.8))
        XCTAssertEqual(out.x, 0.2, accuracy: 1e-4)
        XCTAssertEqual(out.z, 0.8, accuracy: 1e-4)
    }

    func testSCurveIsMonotoneAndPassesThroughPoints() {
        let points = [CurvePoint(0, 0.04), CurvePoint(0.25, 0.2), CurvePoint(0.5, 0.52), CurvePoint(0.75, 0.82), CurvePoint(1, 0.97)]
        let curve = MonotoneCurve(points: points)
        for p in points {
            XCTAssertEqual(curve.evaluate(p.x), p.y, accuracy: 1e-5)
        }
        var previous = curve.evaluate(0)
        for x in stride(from: Float(0.01), through: 1, by: 0.01) {
            let y = curve.evaluate(x)
            XCTAssertGreaterThanOrEqual(y, previous - 1e-6, "x = \(x)")
            previous = y
        }
    }

    func testMissingEndpointsAreAdded() {
        let curve = MonotoneCurve(points: [CurvePoint(0.5, 0.6)])
        XCTAssertEqual(curve.evaluate(0), 0, accuracy: 1e-6)
        XCTAssertEqual(curve.evaluate(1), 1, accuracy: 1e-6)
        XCTAssertEqual(curve.evaluate(0.5), 0.6, accuracy: 1e-5)
    }

    func testCurvesDecodeFromPairs() throws {
        let json = #"{"curves": {"master": [[0, 0.05], [1, 0.95]], "b": [[0.5, 0.45]]}, "fade": 0.04}"#
        let recipe = try JSONDecoder().decode(ToneRecipe.self, from: Data(json.utf8))
        XCTAssertEqual(recipe.curves?.master.count, 2)
        XCTAssertEqual(recipe.curves?.b.first?.y ?? 0, 0.45, accuracy: 1e-6)
        XCTAssertEqual(recipe.curves?.r, [])
        XCTAssertEqual(recipe.fade, 0.04, accuracy: 1e-6)
        let black = recipe.apply(to: RGB(0, 0, 0))
        XCTAssertGreaterThan(black.x, 0.04, "曲线抬起了黑位")
    }

    // MARK: - HSL

    func testNeutralMixerIsIdentity() {
        let recipe = ToneRecipe(hsl: .neutral)
        for probe in [RGB(0.8, 0.3, 0.2), RGB(0.2, 0.6, 0.3), RGB(0.3, 0.4, 0.9)] {
            let out = recipe.apply(to: probe)
            XCTAssertEqual(out.x, probe.x, accuracy: 1e-4)
            XCTAssertEqual(out.y, probe.y, accuracy: 1e-4)
            XCTAssertEqual(out.z, probe.z, accuracy: 1e-4)
        }
    }

    func testGreenBandOnlyMovesGreens() {
        let recipe = ToneRecipe(hsl: HSLMixer(green: HSLBand(hue: 0, saturation: 0.3, luminance: 0)))
        let green = RGB(0.2, 0.7, 0.25)
        let red = RGB(0.8, 0.2, 0.2)
        let greenOut = recipe.apply(to: green)
        let redOut = recipe.apply(to: red)
        XCTAssertLessThan(ColorMath.hsv(greenOut).s, ColorMath.hsv(green).s - 0.2, "绿色被压低饱和")
        XCTAssertEqual(redOut.x, red.x, accuracy: 0.01, "红色不受影响")
        XCTAssertEqual(redOut.y, red.y, accuracy: 0.01)
    }

    func testHueBandWeightsAreSmoothAndSumToOne() {
        var previous = ColorMath.hueBandWeights(0)
        for h in stride(from: Float(0.5), to: 360, by: 0.5) {
            let w = ColorMath.hueBandWeights(h)
            XCTAssertTrue(w.upperWeight >= 0 && w.upperWeight <= 1)
            if w.lower == previous.lower {
                XCTAssertLessThanOrEqual(abs(w.upperWeight - previous.upperWeight), 0.05, "h = \(h)")
            }
            previous = w
        }
    }

    // MARK: - 肤色保护、高光软肩、雾化

    func testSkinProtectKeepsSkinCloserToOriginal() {
        let skin = RGB(0.86, 0.64, 0.52)
        let plain = ToneRecipe(saturation: 1.6).apply(to: skin)
        let protected = ToneRecipe(saturation: 1.6, skinProtect: 1).apply(to: skin)
        let plainShift = ColorMath.hsv(plain).s - ColorMath.hsv(skin).s
        let protectedShift = ColorMath.hsv(protected).s - ColorMath.hsv(skin).s
        XCTAssertGreaterThan(plainShift, 0.05)
        XCTAssertLessThan(protectedShift, plainShift * 0.6)
    }

    func testHighlightRolloffKeepsDetailInsteadOfClipping() {
        let bright = RGB(0.9, 0.9, 0.9)
        let clipped = ToneRecipe(exposure: 1).apply(to: bright)
        let rolled = ToneRecipe(exposure: 1, highlightRolloff: 0.6).apply(to: bright)
        XCTAssertEqual(clipped.x, 1, accuracy: 1e-4)
        XCTAssertLessThan(rolled.x, 0.999)
        XCTAssertGreaterThan(rolled.x, 0.9)
        let darker = ToneRecipe(exposure: 1, highlightRolloff: 0.6).apply(to: RGB(0.8, 0.8, 0.8))
        XCTAssertLessThan(darker.x, rolled.x, "软肩仍然单调")
    }

    func testFadeLiftsShadowsMoreThanHighlights() {
        let recipe = ToneRecipe(fade: 0.1)
        let black = recipe.apply(to: RGB(0, 0, 0))
        let white = recipe.apply(to: RGB(1, 1, 1))
        XCTAssertEqual(black.x, 0.1, accuracy: 1e-4)
        XCTAssertEqual(white.x, 1, accuracy: 1e-4)
    }

    func testNewFieldsRoundTripThroughJSON() throws {
        let recipe = ToneRecipe(
            contrast: 1.1,
            curves: ToneCurves(master: [CurvePoint(0, 0.03), CurvePoint(0.5, 0.52), CurvePoint(1, 0.97)], b: [CurvePoint(0, 0.05)]),
            hsl: HSLMixer(orange: HSLBand(hue: -2, saturation: 0.9, luminance: 0.04), green: HSLBand(hue: 12, saturation: 0.7)),
            fade: 0.05,
            highlightRolloff: 0.5,
            skinProtect: 0.4
        )
        let data = try JSONEncoder().encode(recipe)
        XCTAssertEqual(try JSONDecoder().decode(ToneRecipe.self, from: data), recipe)
    }
}
