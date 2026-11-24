import CoreGraphics
import XCTest
@testable import NocchiKit

/// 软木板的灯光模型（移植自 Typewriter Nocturne 的 light-model.ts）。
final class LightModelTests: XCTestCase {
    private let board = CGSize(width: 1100, height: 620)

    func testSmoothstepAndToneMap() {
        XCTAssertEqual(LightModel.smoothstep(0, 1, -1), 0)
        XCTAssertEqual(LightModel.smoothstep(0, 1, 2), 1)
        XCTAssertEqual(LightModel.smoothstep(0, 1, 0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(LightModel.toneMap(0), 0)
        XCTAssertLessThan(LightModel.toneMap(10), 1)
        XCTAssertEqual(LightModel.toneMap(-3), 0)
    }

    func testDeskLampLightsItsAimPointToTheChosenIntensity() {
        let placement = LightPlacement(source: .deskLamp, x: 0.2, y: 0.15, reach: 0.5, softness: 0.5, intensity: 0.6)
        let rig = LightModel.rig(placement, size: board)
        let w = Double(board.width)
        let h = Double(board.height)
        let aimX = 0.2 * w + (0.5 * w - 0.2 * w) * 0.3
        let aimY = 0.15 * h + (0.5 * h - 0.15 * h) * 0.3
        let target = 0.4 + 1.6 * 0.6
        XCTAssertEqual(LightModel.lightAmount(rig, x: aimX, y: aimY), 1 - exp(-target), accuracy: 1e-6)
        // 光斑外面（板子另一角）暗得多。
        XCTAssertLessThan(LightModel.lightAmount(rig, x: w * 0.98, y: h * 0.98), LightModel.lightAmount(rig, x: aimX, y: aimY) * 0.35)
    }

    func testHigherLampMakesALargerPool() {
        let low = LightModel.rig(LightPlacement(source: .deskLamp, x: 0.5, y: 0.2, reach: 0.1, softness: 0.4, intensity: 0.6), size: board)
        let high = LightModel.rig(LightPlacement(source: .deskLamp, x: 0.5, y: 0.2, reach: 1, softness: 0.4, intensity: 0.6), size: board)
        // 离光斑中心 300 点的地方：灯挂得高，光锥照得到；挂得低，已经出了光锥。
        let x = 0.5 * Double(board.width) + 300
        let y = 0.2 * Double(board.height) + (0.5 - 0.2) * 0.3 * Double(board.height)
        XCTAssertGreaterThan(LightModel.lightAmount(high, x: x, y: y), LightModel.lightAmount(low, x: x, y: y))
    }

    func testSunlightThroughTheWindow() {
        let rig = LightModel.rig(LightPlacement(source: .sunlight, x: 0.15, y: 0.1, reach: 0.5, softness: 0.2, intensity: 0.6), size: board)
        let window = rig.window
        XCTAssertEqual(window.columns, 3)
        XCTAssertEqual(window.rows, 2)
        // 一格窗格的正中：整束光都透过来。
        let paneHeight = window.height / Double(window.rows)
        let middle = LightModel.lightAmount(rig, x: window.x + (window.y - paneHeight / 2 - window.y) * window.skew, y: window.y - paneHeight / 2)
        XCTAssertEqual(middle, 1 - exp(-(0.4 + 1.6 * 0.6)), accuracy: 0.02)
        // 窗外没有光。
        XCTAssertEqual(LightModel.lightAmount(rig, x: window.x + window.width, y: window.y + window.height), 0, accuracy: 1e-6)
        // 光从左上来：往右下走。
        XCTAssertGreaterThan(rig.direction.x, 0)
        XCTAssertGreaterThan(rig.direction.y, 0)
        XCTAssertLessThan(rig.direction.z, 0)
    }

    func testSmallBoardKeepsTheWindowCrisp() {
        // 「灯光」卡片上的小预览：柔边按板子大小缩小，窗格中间照样是满的。
        let small = CGSize(width: 212, height: 118)
        let rig = LightModel.rig(LightPlacement(source: .sunlight, x: 0.16, y: 0.12, reach: 0.55, softness: 0.35, intensity: 0.55), size: small)
        XCTAssertLessThan(rig.window.softness, 8)
        let paneHeight = rig.window.height / Double(rig.window.rows)
        let y = rig.window.y - paneHeight / 2
        let x = rig.window.x + (y - rig.window.y) * rig.window.skew
        XCTAssertGreaterThan(LightModel.windowGobo(rig, x: x, y: y), 0.9)
    }

    func testWindowBarsCastShadows() {
        let rig = LightModel.rig(LightPlacement(source: .moonlight, x: 0.5, y: 0.05, reach: 0.6, softness: 0, intensity: 0.6), size: board)
        let window = rig.window
        let open = LightModel.windowGobo(rig, x: window.x - window.width / 4, y: window.y - window.height / 4)
        // 窗户中间那根竖窗棂（两列时正好在中心线上）。
        let bar = LightModel.windowGobo(rig, x: window.x, y: window.y - window.height / 4)
        XCTAssertEqual(open, 1, accuracy: 1e-6)
        XCTAssertEqual(bar, 0.3, accuracy: 1e-6)
    }
}
