import XCTest
@testable import NocchiKit

final class ColorMathTests: XCTestCase {
    func testSRGBRoundTrip() {
        for v in stride(from: Float(0), through: 1, by: 0.05) {
            XCTAssertEqual(ColorMath.linearToSRGB(ColorMath.srgbToLinear(v)), v, accuracy: 1e-4)
        }
    }

    func testHexParsing() {
        let c = RGB(hex: "#FF8000")
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.x, 1, accuracy: 1e-6)
        XCTAssertEqual(c!.y, 128.0 / 255.0, accuracy: 1e-6)
        XCTAssertEqual(c!.z, 0, accuracy: 1e-6)
        XCTAssertEqual(RGB(hex: "336699")?.hexString, "#336699")
        XCTAssertNil(RGB(hex: "#12345"))
        XCTAssertNil(RGB(hex: "zzzzzz"))
    }

    func testContrastCurveKeepsEndpointsAndPivot() {
        for k in [Float(0.6), 1, 1.5, 2.2] {
            XCTAssertEqual(ColorMath.contrastCurve(0, k), 0, accuracy: 1e-6)
            XCTAssertEqual(ColorMath.contrastCurve(1, k), 1, accuracy: 1e-6)
            XCTAssertEqual(ColorMath.contrastCurve(0.5, k), 0.5, accuracy: 1e-6)
        }
        XCTAssertLessThan(ColorMath.contrastCurve(0.25, 1.6), 0.25)
        XCTAssertGreaterThan(ColorMath.contrastCurve(0.75, 1.6), 0.75)
    }

    func testContrastCurveIsMonotonic() {
        var previous: Float = -1
        for i in 0...100 {
            let y = ColorMath.contrastCurve(Float(i) / 100, 1.8)
            XCTAssertGreaterThanOrEqual(y, previous)
            previous = y
        }
    }

    func testSoftLightNeutralGray() {
        for v in stride(from: Float(0), through: 1, by: 0.1) {
            XCTAssertEqual(ColorMath.softLight(v, 0.5), v, accuracy: 1e-6)
        }
    }

    func testSmoothstep() {
        XCTAssertEqual(ColorMath.smoothstep(0.2, 0.8, 0.1 as Double), 0)
        XCTAssertEqual(ColorMath.smoothstep(0.2, 0.8, 0.9 as Double), 1)
        XCTAssertEqual(ColorMath.smoothstep(0.2, 0.8, 0.5 as Double), 0.5, accuracy: 1e-9)
    }
}

final class ToneRecipeTests: XCTestCase {
    func testNeutralRecipeIsIdentity() {
        let recipe = ToneRecipe.neutral
        for r in stride(from: Float(0), through: 1, by: 0.25) {
            for g in stride(from: Float(0), through: 1, by: 0.25) {
                for b in stride(from: Float(0), through: 1, by: 0.25) {
                    let out = recipe.apply(to: RGB(r, g, b))
                    XCTAssertEqual(out.x, r, accuracy: 1e-4)
                    XCTAssertEqual(out.y, g, accuracy: 1e-4)
                    XCTAssertEqual(out.z, b, accuracy: 1e-4)
                }
            }
        }
    }

    func testMonochromeProducesGray() {
        let recipe = ToneRecipe(monochrome: true)
        let out = recipe.apply(to: RGB(0.9, 0.2, 0.4))
        XCTAssertEqual(out.x, out.y, accuracy: 1e-6)
        XCTAssertEqual(out.y, out.z, accuracy: 1e-6)
    }

    func testBlackLiftFadesBlacks() {
        let recipe = ToneRecipe(blackLift: 0.1, whiteCap: 0.9)
        let black = recipe.apply(to: RGB(0, 0, 0))
        let white = recipe.apply(to: RGB(1, 1, 1))
        XCTAssertEqual(black.x, 0.1, accuracy: 1e-4)
        XCTAssertEqual(white.x, 0.9, accuracy: 1e-4)
    }

    func testWarmTemperatureShiftsTowardsRed() {
        let warm = ToneRecipe(temperature: 0.8).apply(to: RGB(0.5, 0.5, 0.5))
        XCTAssertGreaterThan(warm.x, warm.z)
        let cool = ToneRecipe(temperature: -0.8).apply(to: RGB(0.5, 0.5, 0.5))
        XCTAssertLessThan(cool.x, cool.z)
    }

    func testOutputIsAlwaysInRange() {
        let extreme = ToneRecipe(exposure: 2, temperature: 1, tint: -1, contrast: 2.5, saturation: 2, crossTalk: 0.3,
                                 shadowTint: "#0000FF", shadowTintAmount: 1, highlightTint: "#FF0000", highlightTintAmount: 1)
        for v in stride(from: Float(0), through: 1, by: 0.1) {
            let out = extreme.apply(to: RGB(v, 1 - v, v * 0.5))
            for c in [out.x, out.y, out.z] {
                XCTAssertTrue(c >= 0 && c <= 1 && c.isFinite)
            }
        }
    }

    func testPartialJSONUsesDefaults() throws {
        let json = #"{"contrast": 1.3, "monochrome": true}"#.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(ToneRecipe.self, from: json)
        XCTAssertEqual(recipe.contrast, 1.3, accuracy: 1e-6)
        XCTAssertTrue(recipe.monochrome)
        XCTAssertEqual(recipe.saturation, 1)
        XCTAssertEqual(recipe.whiteCap, 1)
        XCTAssertNil(recipe.shadowTint)
    }
}

final class ColorCubeTests: XCTestCase {
    func testIdentityLookup() {
        let cube = ColorCube.identity(dimension: 9)
        let probe = RGB(0.13, 0.57, 0.91)
        let out = cube.lookup(probe)
        XCTAssertEqual(out.x, probe.x, accuracy: 1e-5)
        XCTAssertEqual(out.y, probe.y, accuracy: 1e-5)
        XCTAssertEqual(out.z, probe.z, accuracy: 1e-5)
    }

    func testBakedNeutralRecipeIsNearIdentity() {
        let cube = LUTBaker.bake(.neutral, dimension: 17)
        XCTAssertEqual(cube.values.count, 17 * 17 * 17 * 4)
        let out = cube.lookup(RGB(0.3, 0.6, 0.9))
        XCTAssertEqual(out.x, 0.3, accuracy: 2e-3)
        XCTAssertEqual(out.y, 0.6, accuracy: 2e-3)
        XCTAssertEqual(out.z, 0.9, accuracy: 2e-3)
        XCTAssertEqual(cube.data.count, cube.values.count * MemoryLayout<Float>.size)
    }

    func testZeroIntensityIsIdentity() {
        let cube = LUTBaker.bake(ToneRecipe(monochrome: true), dimension: 9, intensity: 0)
        let out = cube.lookup(RGB(1, 0, 0))
        XCTAssertEqual(out.x, 1, accuracy: 1e-5)
        XCTAssertEqual(out.y, 0, accuracy: 1e-5)
    }

    func testCubeTextRoundTrip() throws {
        let cube = LUTBaker.bake(ToneRecipe(contrast: 1.4, saturation: 0.7), dimension: 5)
        let text = cube.cubeText(title: "Round \"Trip\"")
        let parsed = try CubeLUT(parsing: text)
        XCTAssertEqual(parsed.size, 5)
        XCTAssertEqual(parsed.kind, .threeD)
        let again = parsed.colorCube()
        XCTAssertEqual(again.dimension, 5)
        for i in 0..<cube.values.count {
            XCTAssertEqual(again.values[i], cube.values[i], accuracy: 1e-5)
        }
    }
}
