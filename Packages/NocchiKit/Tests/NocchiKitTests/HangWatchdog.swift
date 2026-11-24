import Foundation
import XCTest

/// 测试看门狗：任何一个测试跑了超过 90 秒（平时最慢的也不到 10 秒），就把测试名写到 stderr 并结束进程。
///
/// CI 上测试进程的 stdout 是整块缓冲的，测试卡住、被超时杀掉时最后几屏输出会丢，看不出是哪个测试卡住；
/// 看门狗退出前会先把缓冲区写出去，日志尾部就是卡住的那个测试。
final class HangWatchdog: NSObject, XCTestObservation {
    static let shared = HangWatchdog()
    static let limit: TimeInterval = 90

    private let queue = DispatchQueue(label: "nocchi.test-watchdog")
    private var timer: DispatchSourceTimer?
    private var installed = false

    func install() {
        guard !installed else { return }
        installed = true
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        let name = testCase.name
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.limit)
        timer.setEventHandler {
            let message = "\n⏱ HANG: \(name) 超过 \(Int(Self.limit)) 秒还没结束，结束测试进程。\n"
            fflush(stdout)
            FileHandle.standardError.write(Data(message.utf8))
            exit(3)
        }
        timer.resume()
        self.timer?.cancel()
        self.timer = timer
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        timer?.cancel()
        timer = nil
    }
}

/// 名字排在最前面（XCTest 按类名字母顺序跑），第一个运行，给后面所有测试装上看门狗。
final class AAAWatchdogTests: XCTestCase {
    func testInstallWatchdog() {
        HangWatchdog.shared.install()
    }
}
