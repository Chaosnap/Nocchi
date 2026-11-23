import CoreGraphics
import XCTest
@testable import NocchiKit

final class SoundSynthTests: XCTestCase {
    func testEveryEffectRendersAudibleFiniteSamples() {
        for effect in SoundEffect.allCases {
            let samples = SoundSynth.render(effect)
            XCTAssertGreaterThan(samples.count, 1000, "\(effect)")
            XCTAssertTrue(samples.allSatisfy { $0.isFinite }, "\(effect) has NaN/Inf")
            let peak = samples.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0.5, "\(effect) too quiet")
            XCTAssertLessThanOrEqual(peak, 0.851, "\(effect) clipped")
        }
    }

    func testMotorDurationIsRespected() {
        let samples = SoundSynth.render(.motor, duration: 3.0)
        XCTAssertEqual(Double(samples.count) / SoundSynth.sampleRate, 3.0, accuracy: 0.01)
    }

    func testRenderingIsDeterministic() {
        XCTAssertEqual(SoundSynth.render(.tear), SoundSynth.render(.tear))
    }
}

final class GeometryTests: XCTestCase {
    func testHardwareNotch() {
        // 14 英寸 MacBook Pro 默认缩放：1512 × 982，刘海约 185pt 宽、32pt 高。
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let metrics = NotchMetrics.compute(screenFrame: frame, safeAreaTop: 32, leftAreaWidth: 663.5, rightAreaWidth: 663.5, menuBarHeight: 32)
        XCTAssertTrue(metrics.isHardware)
        XCTAssertEqual(metrics.rect.width, 185, accuracy: 0.01)
        XCTAssertEqual(metrics.rect.maxY, 982)
        XCTAssertEqual(metrics.rect.midX, 756, accuracy: 0.01)
        XCTAssertTrue(metrics.hoverZone.contains(CGPoint(x: 756, y: 970)))
    }

    func testVirtualNotchOnExternalDisplay() {
        let frame = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let metrics = NotchMetrics.compute(screenFrame: frame, safeAreaTop: 0, leftAreaWidth: nil, rightAreaWidth: nil, menuBarHeight: 25)
        XCTAssertFalse(metrics.isHardware)
        XCTAssertEqual(metrics.rect.midX, frame.midX, accuracy: 0.01)
        XCTAssertEqual(metrics.rect.height, 25)
        XCTAssertEqual(metrics.rect.maxY, 1440)
    }

    func testDynamicIslandEstimate() {
        let island = IslandMetrics.estimate(screenWidth: 393, safeAreaTop: 59)
        XCTAssertEqual(island.kind, .dynamicIsland)
        XCTAssertEqual(island.rect.minY, 11, accuracy: 0.01)
        XCTAssertEqual(island.rect.midX, 196.5, accuracy: 0.01)
        let slot = island.slotRect(paperWidth: 200)
        XCTAssertEqual(slot.width, 226, accuracy: 0.01)
        XCTAssertEqual(slot.midX, island.rect.midX, accuracy: 0.01)
    }

    func testNotchAndHomeButtonPhones() {
        XCTAssertEqual(IslandMetrics.estimate(screenWidth: 390, safeAreaTop: 47).kind, .notch)
        let se = IslandMetrics.estimate(screenWidth: 375, safeAreaTop: 20)
        XCTAssertEqual(se.kind, .none)
        XCTAssertGreaterThanOrEqual(se.rect.minY, 20)
    }
}
