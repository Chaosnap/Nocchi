import CoreGraphics
import CoreImage
import XCTest
@testable import NocchiKit

/// Core Image 管线必须忠实地套用配方：同一个颜色，`FilmProcessor` 冲出来的结果要和 CPU 上查同一个立方体的结果一致。
///
/// 截图工作室在 CI 上冲出来的照片整体暗了一个 gamma、饱和度也偏高，而离线预览（scripts/film/preview_looks.py）
/// 是对的——说明问题出在 Core Image 一侧的色彩转换。这组测试把它钉住。
final class FilmPipelineFidelityTests: XCTestCase {
    private let processor = TestContext.processor

    /// 只留色调（去掉颗粒、暗角、光晕等效果），管线就只剩「裁剪 → 查表」。
    private func toneOnly(_ id: String) -> FilmStock {
        var stock = FilmCatalog.stock(id: id)
        XCTAssertEqual(stock.id, id)
        stock.effects = FilmEffects()
        return stock
    }

    private static let patches: [(Double, Double, Double)] = [
        (0.18, 0.16, 0.14),
        (0.42, 0.38, 0.33),
        (0.60, 0.55, 0.50),
        (0.82, 0.78, 0.70),
        (0.30, 0.55, 0.85)
    ]

    func testLUTStageMatchesTheRecipeOnFlatPatches() throws {
        for id in ["cream-600", "sunset-200", "mint-400", "grit-400"] {
            let stock = toneOnly(id)
            let cube = processor.cube(for: stock)
            for (r, g, b) in Self.patches {
                let input = TestImages.solid(CGFloat(r), CGFloat(g), CGFloat(b), width: 48, height: 48)
                let output = try XCTUnwrap(processor.process(input, stock: stock, options: ProcessOptions(maxLongEdge: 48, seed: 1)))
                let pixel = PixelBuffer(output).rgb(24, 24)
                let expected = cube.lookup(RGB(Float(r), Float(g), Float(b)))
                let label = "\(id) at (\(r), \(g), \(b)): got \(pixel), expected \(expected)"
                XCTAssertEqual(Double(pixel.r) / 255, Double(expected.x), accuracy: 0.035, label)
                XCTAssertEqual(Double(pixel.g) / 255, Double(expected.y), accuracy: 0.035, label)
                XCTAssertEqual(Double(pixel.b) / 255, Double(expected.z), accuracy: 0.035, label)
            }
        }
    }

    func testNeutralStockLeavesTheImageAlone() throws {
        var stock = toneOnly("cream-600")
        stock.tone = ToneRecipe()
        for (r, g, b) in Self.patches {
            let input = TestImages.solid(CGFloat(r), CGFloat(g), CGFloat(b), width: 32, height: 32)
            let output = try XCTUnwrap(processor.process(input, stock: stock, options: ProcessOptions(maxLongEdge: 32, seed: 1)))
            let pixel = PixelBuffer(output).rgb(16, 16)
            XCTAssertEqual(Double(pixel.r) / 255, r, accuracy: 0.02, "neutral R at \(r)")
            XCTAssertEqual(Double(pixel.g) / 255, g, accuracy: 0.02, "neutral G at \(g)")
            XCTAssertEqual(Double(pixel.b) / 255, b, accuracy: 0.02, "neutral B at \(b)")
        }
    }

    /// 只记录、不断言：旧写法（`CIColorCubeWithColorSpace`）在这台机器上冲出来是什么颜色，写成一条 CI 注解，方便对照。
    func testReportWhatTheOldColorCubeFilterDoes() throws {
        let stock = toneOnly("cream-600")
        let cube = processor.cube(for: stock)
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let input = CIImage(cgImage: TestImages.solid(0.6, 0.55, 0.5, width: 8, height: 8))
        let old = input.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": cube.dimension,
            "inputCubeData": cube.data,
            "inputColorSpace": sRGB
        ])
        let rendered = try XCTUnwrap(processor.context.createCGImage(old, from: CGRect(x: 0, y: 0, width: 8, height: 8), format: .RGBA8, colorSpace: sRGB))
        let oldPixel = PixelBuffer(rendered).rgb(4, 4)
        let newPixel = PixelBuffer(try XCTUnwrap(processor.process(TestImages.solid(0.6, 0.55, 0.5, width: 8, height: 8), stock: stock, options: ProcessOptions(maxLongEdge: 8, seed: 1)))).rgb(4, 4)
        let e = cube.lookup(RGB(0.6, 0.55, 0.5))
        print("::notice title=Film fidelity::cream-600 on (153,140,128): CIColorCubeWithColorSpace \(oldPixel.r),\(oldPixel.g),\(oldPixel.b) · pipeline \(newPixel.r),\(newPixel.g),\(newPixel.b) · recipe \(Int((e.x * 255).rounded())),\(Int((e.y * 255).rounded())),\(Int((e.z * 255).rounded()))")
    }

    func testFullPipelineKeepsTheBrightnessOfTheRecipe() throws {
        // 已知问题（2026-11-24，未修）：打开颗粒 / 暗角 / 光晕等效果后，160 × 160 的平坦色块中间量出来是 0（全黑），
        // 截图里的照片也整体偏暗；色调查表这一步是对的（见上一条测试的注解）。交接说明见 docs/PROGRESS.md「照片偏暗」。
        // 修好之后删掉这一行，这条测试应该直接通过。
        XCTExpectFailure("效果阶段会把照片压暗（见 docs/PROGRESS.md「照片偏暗」），待修", strict: true)
        let color = RGB(0.55, 0.5, 0.45)
        for id in ["cream-600", "portrait-400", "sunset-200", "mint-400", "neon-800"] {
            let stock = FilmCatalog.stock(id: id)
            let input = TestImages.solid(0.55, 0.5, 0.45, width: 160, height: 160)
            let output = PixelBuffer(try XCTUnwrap(processor.process(input, stock: stock, options: ProcessOptions(maxLongEdge: 160, seed: 3))))
            // 中间一块（暗角只压四角）。
            var sum = 0.0
            var count = 0
            for y in 60..<100 {
                for x in 60..<100 {
                    let p = output.rgb(x, y)
                    sum += 0.2126 * Double(p.r) + 0.7152 * Double(p.g) + 0.0722 * Double(p.b)
                    count += 1
                }
            }
            let measured = sum / Double(count) / 255
            let e = processor.cube(for: stock).lookup(color)
            let expected = 0.2126 * Double(e.x) + 0.7152 * Double(e.y) + 0.0722 * Double(e.z)
            XCTAssertEqual(measured, expected, accuracy: 0.1, "\(id): measured \(measured), recipe \(expected)")
        }
    }
}
