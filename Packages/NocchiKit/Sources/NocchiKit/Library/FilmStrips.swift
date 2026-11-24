import Foundation

/// 光台上的一条胶片：普通照片拼成的 35mm 正片条，或者一整条大头贴。
public struct FilmStrip: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        /// 普通照片：每张一格，按卷、按月拼成一条。
        case roll
        /// 大头贴：一张成片就是一条，每格一张底片。
        case booth
    }

    /// 胶片上的一格。
    public struct Frame: Hashable, Sendable {
        public let recordID: UUID
        /// 用这张照片的第几张底片（普通照片总是 0；大头贴 0…3）。
        public let negativeIndex: Int

        public init(recordID: UUID, negativeIndex: Int) {
            self.recordID = recordID
            self.negativeIndex = negativeIndex
        }
    }

    /// 「roll-<第一张照片的 UUID>」或「booth-<照片的 UUID>」。
    public let id: String
    public let kind: Kind
    public let stockID: String
    public let stockName: String
    public let frames: [Frame]
    /// 第一格的拍摄时间（`displayDate`）。
    public let startDate: Date
    /// 「2026-11」（第一格的 `displayDate`，当前时区）。
    public let monthKey: String
    /// 这一条第一格在当月的帧号（从 1 开始；只数普通照片）。大头贴条总是 1。
    public let firstFrameNumber: Int

    public init(id: String, kind: Kind, stockID: String, stockName: String, frames: [Frame], startDate: Date, monthKey: String, firstFrameNumber: Int) {
        self.id = id
        self.kind = kind
        self.stockID = stockID
        self.stockName = stockName
        self.frames = frames
        self.startDate = startDate
        self.monthKey = monthKey
        self.firstFrameNumber = firstFrameNumber
    }
}

/// 把照片排成胶片条（相册的「胶卷」模式）。
public enum FilmStrips {
    /// 旧 → 新排成胶片条：大头贴一张一条；其余每 framesPerStrip 张一条，不跨月、不跨胶卷。
    ///
    /// - 照片按 `displayDate` 从旧到新排（同一时刻再按 `createdAt`、`id`）；没有底片的照片跳过。
    /// - 大头贴（`format.isBooth`）：一张一条，每张底片一格。
    /// - 其余照片：同一个月（`displayDate` 的「yyyy-MM」，当前时区）、同一卷胶卷（`stockID`）里
    ///   连续拍的照片拼成一条，每张一格（第 0 张底片），满 `framesPerStrip` 格换下一条。
    ///   大头贴是另一台机器拍的，夹在中间不会打断胶卷；换胶卷或跨月就另起一条。
    /// - `firstFrameNumber` 是这一条第一格在当月普通照片里的序号（从 1 开始，换胶卷也接着数）。
    /// - 结果按每条第一格的先后排列。`framesPerStrip` 小于 1 时按 1 处理。
    public static func make(from records: [PhotoRecord], framesPerStrip: Int = 4) -> [FilmStrip] {
        let capacity = max(1, framesPerStrip)
        let calendar = PhotoCalendar.localGregorian()
        let sorted = records.filter { !$0.negatives.isEmpty }.sorted(by: PhotoCalendar.oldestFirst)

        var output: [(order: Int, strip: FilmStrip)] = []
        var run: Run?
        var countingMonth: String?
        var frameNumber = 0

        for (index, record) in sorted.enumerated() {
            let month = PhotoCalendar.monthKey(record.displayDate, calendar: calendar)
            if record.format.isBooth {
                output.append((order: index, strip: boothStrip(record, monthKey: month)))
                continue
            }
            if month != countingMonth {
                countingMonth = month
                frameNumber = 0
            }
            frameNumber += 1
            if let current = run,
               current.monthKey != month || current.first.stockID != record.stockID || current.records.count >= capacity {
                output.append((order: current.order, strip: rollStrip(current)))
                run = nil
            }
            if run == nil {
                run = Run(order: index, monthKey: month, firstFrameNumber: frameNumber, first: record, records: [record])
            } else {
                run?.records.append(record)
            }
        }
        if let current = run {
            output.append((order: current.order, strip: rollStrip(current)))
        }
        return output.sorted { $0.order < $1.order }.map { $0.strip }
    }

    // MARK: - 内部

    /// 正在拼的一条普通胶片。
    private struct Run {
        /// 第一格在排好序的照片里的位置（决定输出顺序）。
        let order: Int
        let monthKey: String
        let firstFrameNumber: Int
        let first: PhotoRecord
        var records: [PhotoRecord]
    }

    private static func rollStrip(_ run: Run) -> FilmStrip {
        FilmStrip(
            id: "roll-" + run.first.id.uuidString,
            kind: .roll,
            stockID: run.first.stockID,
            stockName: run.first.stockName,
            frames: run.records.map { FilmStrip.Frame(recordID: $0.id, negativeIndex: 0) },
            startDate: run.first.displayDate,
            monthKey: run.monthKey,
            firstFrameNumber: run.firstFrameNumber
        )
    }

    private static func boothStrip(_ record: PhotoRecord, monthKey: String) -> FilmStrip {
        FilmStrip(
            id: "booth-" + record.id.uuidString,
            kind: .booth,
            stockID: record.stockID,
            stockName: record.stockName,
            frames: record.negatives.indices.map { FilmStrip.Frame(recordID: record.id, negativeIndex: $0) },
            startDate: record.displayDate,
            monthKey: monthKey,
            firstFrameNumber: 1
        )
    }
}
