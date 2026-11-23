import CoreGraphics
import XCTest
@testable import NocchiKit

final class DevelopmentModelTests: XCTestCase {
    func testDevelopsInBaseDurationWithoutShaking() {
        var model = DevelopmentModel(baseDuration: 10)
        for _ in 0..<99 { model.advance(by: 0.1) }
        XCTAssertFalse(model.isComplete)
        model.advance(by: 0.2)
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.progress, 1)
    }

    func testShakingSpeedsUpDevelopment() {
        var calm = DevelopmentModel(baseDuration: 10)
        var shaken = DevelopmentModel(baseDuration: 10)
        for _ in 0..<30 {
            calm.advance(by: 0.1)
            shaken.addShake(energy: 1)
            shaken.advance(by: 0.1)
        }
        XCTAssertGreaterThan(shaken.progress, calm.progress * 1.8)
        XCTAssertLessThanOrEqual(shaken.boost, shaken.maxBoost)
    }

    func testStartDelay() {
        var model = DevelopmentModel(baseDuration: 4, startDelay: 2)
        model.advance(by: 1.5)
        XCTAssertEqual(model.progress, 0)
        XCTAssertFalse(model.hasStarted)
        model.advance(by: 1.5)
        XCTAssertEqual(model.progress, 0.25, accuracy: 1e-9)
        XCTAssertEqual(model.remaining, 3, accuracy: 1e-9)
    }

    func testVisualAtCompletionIsExactlyTheFinalImage() {
        XCTAssertEqual(DevelopmentVisual.at(1), .developed)
        XCTAssertEqual(DevelopmentVisual.at(5), .developed)
        let start = DevelopmentVisual.at(0)
        XCTAssertEqual(start.imageOpacity, 0)
        XCTAssertGreaterThan(start.hazeOpacity, 0.3)
    }

    func testVisualOpacityIsMonotonic() {
        var previous = -1.0
        for i in 0...100 {
            let v = DevelopmentVisual.at(Double(i) / 100)
            XCTAssertGreaterThanOrEqual(v.imageOpacity, previous)
            previous = v.imageOpacity
        }
    }

    func testCompleteJumpsToEnd() {
        var model = DevelopmentModel(baseDuration: 15, startDelay: 3)
        model.complete()
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.remaining, 0, accuracy: 1e-9)
    }
}

final class ShakeDetectorTests: XCTestCase {
    func testBackAndForthIsDetected() {
        var detector = ShakeDetector(config: .mouse)
        var events: [ShakeDetector.Event] = []
        var t = 0.0
        for i in 0..<40 {
            let x = (i % 2 == 0) ? 0.0 : 120.0
            if let e = detector.add(position: CGPoint(x: x, y: 0), at: t) { events.append(e) }
            t += 0.05 // 120 点 / 0.05 秒 = 2400 点每秒
        }
        XCTAssertGreaterThan(events.count, 20)
        XCTAssertFalse(events.contains { $0.isViolent }, "2400pt/s 还不算很猛")
    }

    func testSlowMovementIsIgnored() {
        var detector = ShakeDetector(config: .mouse)
        var count = 0
        var t = 0.0
        for i in 0..<40 {
            let x = (i % 2 == 0) ? 0.0 : 5.0
            if detector.add(position: CGPoint(x: x, y: 0), at: t) != nil { count += 1 }
            t += 0.05
        }
        XCTAssertEqual(count, 0)
    }

    func testOneDirectionDragIsNotAShake() {
        var detector = ShakeDetector(config: .mouse)
        var count = 0
        for i in 0..<60 {
            if detector.add(position: CGPoint(x: Double(i) * 60, y: 0), at: Double(i) * 0.016) != nil { count += 1 }
        }
        XCTAssertEqual(count, 0)
    }

    func testViolentShakeIsFlagged() {
        var detector = ShakeDetector(config: .mouse)
        var violent = false
        var t = 0.0
        for i in 0..<30 {
            let x = (i % 2 == 0) ? 0.0 : 400.0
            if let e = detector.add(position: CGPoint(x: x, y: 0), at: t), e.isViolent { violent = true }
            t += 0.06 // 400 / 0.06 ≈ 6667 点每秒，约 16 次反转每秒
        }
        XCTAssertTrue(violent)
    }

    func testAccelerometerConfig() {
        var detector = ShakeDetector(config: .accelerometer)
        var count = 0
        for i in 0..<20 {
            let a = SIMD2<Double>((i % 2 == 0) ? 1.8 : -1.8, 0)
            if detector.add(vector: a, at: Double(i) * 0.08) != nil { count += 1 }
        }
        XCTAssertGreaterThan(count, 10)
    }
}

final class PaperLayoutTests: XCTestCase {
    func testWindowsFitInsidePaper() {
        for format in FilmFormat.allCases {
            let layout = format.layout
            let paper = CGRect(origin: .zero, size: layout.paperSize)
            for window in layout.windows {
                XCTAssertTrue(paper.contains(window), "\(format) window \(window)")
            }
            XCTAssertTrue(paper.contains(layout.captionArea), "\(format) caption")
            for window in layout.windows {
                XCTAssertFalse(window.intersects(layout.captionArea), "\(format) caption overlaps image")
            }
        }
    }

    func testInstantSquareHasThickBottomBorder() {
        let layout = PaperLayout.instantSquare
        let window = layout.windows[0]
        XCTAssertEqual(layout.windowAspect, 1, accuracy: 1e-9)
        let bottom = layout.paperSize.height - window.maxY
        XCTAssertGreaterThan(bottom, window.minY * 3)
    }

    func testBoothStripHasFourFrames() {
        XCTAssertEqual(PaperLayout.boothStrip.windows.count, 4)
        XCTAssertEqual(CameraBody.photoBooth.framesPerShot, 4)
        XCTAssertEqual(CameraBody.photoBooth.format, .boothStrip)
    }

    func testScaling() {
        let layout = PaperLayout.instantSquare
        let size = layout.size(forWidth: 176)
        XCTAssertEqual(size.width, 176)
        XCTAssertEqual(size.height, 214, accuracy: 0.01)
        let window = layout.scaled(layout.windows[0], toWidth: 176)
        XCTAssertEqual(window.minX, 9, accuracy: 1e-9)
    }

    func testAvailableBodiesForMVP() {
        XCTAssertEqual(CameraBody.allCases.filter(\.isAvailable), [.instant, .photoBooth])
    }
}

final class FilmRollTests: XCTestCase {
    func testExposeUntilFinished() {
        var roll = FilmRoll(stockID: "x", capacity: 3)
        XCTAssertEqual(roll.counterText, "1/3")
        XCTAssertTrue(roll.expose())
        XCTAssertTrue(roll.expose())
        XCTAssertEqual(roll.remaining, 1)
        XCTAssertTrue(roll.expose())
        XCTAssertTrue(roll.isFinished)
        XCTAssertFalse(roll.expose())
        XCTAssertEqual(roll.counterText, "3/3")
    }

    func testBoothUsesFourFrames() {
        var roll = FilmRoll(stockID: "x", capacity: 16)
        roll.expose(frames: 4)
        XCTAssertEqual(roll.shotsTaken, 4)
    }

    func testReload() {
        var roll = FilmRoll(stockID: "x", capacity: 2, shotsTaken: 2)
        roll.reload(with: FilmCatalog.defaultStock)
        XCTAssertEqual(roll.shotsTaken, 0)
        XCTAssertEqual(roll.rollNumber, 2)
        XCTAssertEqual(roll.stockID, FilmCatalog.defaultStock.id)
    }

    func testWashReadyNextMorning() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let finish = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 22, minute: 15))!
        let ready = FilmRoll.washReadyDate(after: finish, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: ready)
        XCTAssertEqual(parts.day, 24)
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 0)
    }
}

final class BlotchTests: XCTestCase {
    func testDeterministicAndInRange() {
        for i in 0..<20 {
            let a = Blotch.make(seed: 1234, index: i)
            let b = Blotch.make(seed: 1234, index: i)
            XCTAssertEqual(a, b)
            XCTAssertTrue((0...1).contains(a.x) && (0...1).contains(a.y))
            XCTAssertTrue((0.05...0.3).contains(a.radius))
            XCTAssertNotNil(RGB(hex: a.color))
        }
        XCTAssertNotEqual(Blotch.make(seed: 1, index: 0), Blotch.make(seed: 2, index: 0))
    }
}
