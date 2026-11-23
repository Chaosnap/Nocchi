import Foundation

/// 装在机身里的一卷胶卷。
///
/// 默认只是「计数 + 拍完自动换卷」的仪式感，不限制日常截图；
/// 打开严格模式后，拍完要手动换卷。
public struct FilmRoll: Codable, Equatable, Sendable {
    public var stockID: String
    public var capacity: Int
    public var shotsTaken: Int
    public var loadedAt: Date
    /// 第几卷（换卷时 +1）。
    public var rollNumber: Int

    public init(stockID: String, capacity: Int, shotsTaken: Int = 0, loadedAt: Date = Date(), rollNumber: Int = 1) {
        self.stockID = stockID
        self.capacity = max(1, capacity)
        self.shotsTaken = max(0, shotsTaken)
        self.loadedAt = loadedAt
        self.rollNumber = max(1, rollNumber)
    }

    public init(stock: FilmStock, rollNumber: Int = 1) {
        self.init(stockID: stock.id, capacity: stock.exposures, rollNumber: rollNumber)
    }

    public var remaining: Int { max(0, capacity - shotsTaken) }
    public var isFinished: Bool { shotsTaken >= capacity }

    /// 计数器文案：「7/12」。
    public var counterText: String { "\(min(shotsTaken + 1, capacity))/\(capacity)" }

    /// 曝光一次（拍 n 格）。返回 false 表示这卷已经拍完。
    @discardableResult
    public mutating func expose(frames: Int = 1) -> Bool {
        guard !isFinished else { return false }
        shotsTaken = min(capacity, shotsTaken + max(1, frames))
        return true
    }

    /// 换一卷新的同款或其他胶卷。
    public mutating func reload(with stock: FilmStock) {
        stockID = stock.id
        capacity = max(1, stock.exposures)
        shotsTaken = 0
        loadedAt = Date()
        rollNumber += 1
    }

    /// 一次性相机「送洗」：拍完后第二天早上 8 点冲好。
    public static func washReadyDate(after finish: Date, calendar: Calendar = .current, hour: Int = 8) -> Date {
        let startOfNextDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: finish) ?? finish)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfNextDay) ?? startOfNextDay
    }
}
