import XCTest
@testable import NocchiKit

final class CubeLUTTests: XCTestCase {
    private let identity2 = """
    # comment line
    TITLE "Tiny Identity"
    LUT_3D_SIZE 2
    DOMAIN_MIN 0 0 0
    DOMAIN_MAX 1 1 1
    0 0 0
    1 0 0
    0 1 0
    1 1 0
    0 0 1
    1 0 1
    0 1 1
    1 1 1
    """

    func testParsesTinyIdentity() throws {
        let lut = try CubeLUT(parsing: identity2)
        XCTAssertEqual(lut.title, "Tiny Identity")
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.entries.count, 8)
        let mid = lut.map(RGB(0.25, 0.5, 0.75))
        XCTAssertEqual(mid.x, 0.25, accuracy: 1e-5)
        XCTAssertEqual(mid.y, 0.5, accuracy: 1e-5)
        XCTAssertEqual(mid.z, 0.75, accuracy: 1e-5)
    }

    func testCRLFAndInlineCommentsAndTabs() throws {
        let text = identity2
            .replacingOccurrences(of: "\n", with: "\r\n")
            .replacingOccurrences(of: "1 1 1", with: "1\t1\t1 # last")
        let lut = try CubeLUT(parsing: text)
        XCTAssertEqual(lut.entries.last, RGB(1, 1, 1))
    }

    func testMissingSize() {
        XCTAssertThrowsError(try CubeLUT(parsing: "0 0 0\n1 1 1\n")) { error in
            XCTAssertEqual(error as? CubeLUT.ParseError, .missingSize)
        }
    }

    func testCountMismatch() {
        let text = "LUT_3D_SIZE 2\n0 0 0\n1 1 1\n"
        XCTAssertThrowsError(try CubeLUT(parsing: text)) { error in
            XCTAssertEqual(error as? CubeLUT.ParseError, .entryCountMismatch(expected: 8, actual: 2))
        }
    }

    func testRejectsNonFiniteValues() {
        let text = identity2.replacingOccurrences(of: "1 0 1", with: "nan 0 1")
        XCTAssertThrowsError(try CubeLUT(parsing: text)) { error in
            guard case .nonFiniteValue = error as? CubeLUT.ParseError else {
                return XCTFail("expected nonFiniteValue, got \(error)")
            }
        }
    }

    func testRejectsInvalidSize() {
        XCTAssertThrowsError(try CubeLUT(parsing: "LUT_3D_SIZE 1\n0 0 0\n")) { error in
            XCTAssertEqual(error as? CubeLUT.ParseError, .invalidSize(1))
        }
    }

    func testRejectsInvalidDomain() {
        let text = identity2.replacingOccurrences(of: "DOMAIN_MAX 1 1 1", with: "DOMAIN_MAX 0 1 1")
        XCTAssertThrowsError(try CubeLUT(parsing: text)) { error in
            XCTAssertEqual(error as? CubeLUT.ParseError, .invalidDomain)
        }
    }

    func testMalformedLine() {
        let text = identity2.replacingOccurrences(of: "0 1 1", with: "0 1")
        XCTAssertThrowsError(try CubeLUT(parsing: text))
    }

    func testOneDimensionalLUTIsConvertedToCube() throws {
        // 1D：把每个通道反相。
        let text = "LUT_1D_SIZE 3\n1 1 1\n0.5 0.5 0.5\n0 0 0\n"
        let lut = try CubeLUT(parsing: text)
        XCTAssertEqual(lut.kind, .oneD)
        let cube = lut.colorCube()
        XCTAssertEqual(cube.dimension, LUTBaker.defaultDimension)
        let out = cube.lookup(RGB(0, 0.25, 1))
        XCTAssertEqual(out.x, 1, accuracy: 1e-3)
        XCTAssertEqual(out.y, 0.75, accuracy: 1e-2)
        XCTAssertEqual(out.z, 0, accuracy: 1e-3)
    }

    func testNonStandardDomainIsResampled() throws {
        // 定义域 0…2：输入 1.0 对应 LUT 的中点。
        let text = identity2.replacingOccurrences(of: "DOMAIN_MAX 1 1 1", with: "DOMAIN_MAX 2 2 2")
        let lut = try CubeLUT(parsing: text)
        let cube = lut.colorCube()
        let out = cube.lookup(RGB(1, 1, 1))
        XCTAssertEqual(out.x, 0.5, accuracy: 1e-3)
    }

    func testFileSizeLimit() throws {
        let dir = temporaryDirectory("lut-size")
        let url = dir.appendingPathComponent("huge.cube")
        let big = Data(count: CubeLUT.maxFileBytes + 10)
        try big.write(to: url)
        XCTAssertThrowsError(try CubeLUT(contentsOf: url)) { error in
            guard case .fileTooLarge = error as? CubeLUT.ParseError else {
                return XCTFail("expected fileTooLarge, got \(error)")
            }
        }
    }

    func testIntensityBlend() throws {
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
        let lut = try CubeLUT(parsing: inverted)
        let half = lut.colorCube(intensity: 0.5).lookup(RGB(0, 0, 0))
        XCTAssertEqual(half.x, 0.5, accuracy: 1e-4)
        XCTAssertEqual(half.z, 0.5, accuracy: 1e-4)
    }
}
