import CoreGraphics
import Foundation

/// 照片来源。
public enum PhotoSource: String, Codable, Sendable {
    /// Nocchi 自己的屏幕快门（框选截图）。
    case screen
    /// 接管的系统截图（⇧⌘3 / ⇧⌘4）。
    case systemScreenshot
    /// 前置摄像头自拍。
    case selfie
    /// 大头贴机四连拍。
    case booth
    /// iPhone 相机。
    case camera
    /// 从相册冲印。
    case library
}

/// 手写笔画上的一个点。x、y、w 都以相纸宽度为单位（x ∈ 0…1，y ∈ 0…1/aspect）。
public struct InkPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double

    public init(x: Double, y: Double, w: Double) {
        self.x = x
        self.y = y
        self.w = w
    }
}

/// 一笔手写。
public struct InkStroke: Codable, Hashable, Sendable {
    public var points: [InkPoint]
    public var color: String

    public init(points: [InkPoint] = [], color: String) {
        self.points = points
        self.color = color
    }

    /// 根据压感（0…1）计算笔画宽度（相纸宽度单位）。
    public static func width(pressure: Double) -> Double {
        0.0035 + 0.0095 * min(max(pressure, 0), 1)
    }

    /// 根据手指移动速度（点 / 秒）计算笔画宽度：越快越细，像马克笔。
    public static func width(speed: Double) -> Double {
        let k = min(max(speed / 1400, 0), 1)
        return 0.011 - 0.006 * k
    }
}

/// 一帧画面相对图像窗口的错位（大头贴机的轻微错位）。
public struct FrameOffset: Codable, Hashable, Sendable {
    public var dx: Double
    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public static let zero = FrameOffset(dx: 0, dy: 0)
}

/// 照片在桌面上的位置。
public struct DeskPlacement: Codable, Hashable, Sendable {
    public enum Layer: String, Codable, Sendable {
        /// 浮在所有窗口上面。
        case floating
        /// 贴在桌面层（在其他窗口后面）。
        case desktop
    }

    /// Mac：窗口原点（全局屏幕坐标）；iPhone：照片中心（桌面坐标）。
    public var x: Double
    public var y: Double
    /// 倾斜角度（度）。
    public var rotation: Double
    public var layer: Layer

    public init(x: Double, y: Double, rotation: Double, layer: Layer = .floating) {
        self.x = x
        self.y = y
        self.rotation = rotation
        self.layer = layer
    }
}

/// 一张照片的全部信息（底片文件、手写、色块、位置……）。
public struct PhotoRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var source: PhotoSource
    public var body: CameraBody
    public var stockID: String
    public var stockName: String
    public var format: FilmFormat
    public var seed: UInt64
    /// 冲印好的底片（每格一张），相对照片库 negatives 目录。
    public var negatives: [String]
    public var frameOffsets: [FrameOffset]
    public var strokes: [InkStroke]
    /// 打字的题字（白边上的一行字）。
    public var caption: String?
    /// 是否在白边上印日期。
    public var showsDate: Bool
    public var blotches: [Blotch]
    public var developed: Bool
    /// 带白边的成片，相对照片库 prints 目录。
    public var printFile: String?
    /// 在桌面上的位置；nil 表示只在相册里。
    public var desk: DeskPlacement?
    /// 撕开后的另一半。
    public var tornFrom: UUID?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: PhotoSource,
        body: CameraBody,
        stock: FilmStock,
        seed: UInt64,
        negatives: [String] = [],
        frameOffsets: [FrameOffset] = [],
        strokes: [InkStroke] = [],
        caption: String? = nil,
        showsDate: Bool = true,
        blotches: [Blotch] = [],
        developed: Bool = false,
        printFile: String? = nil,
        desk: DeskPlacement? = nil,
        tornFrom: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.body = body
        self.stockID = stock.id
        self.stockName = stock.name
        self.format = body.format
        self.seed = seed
        self.negatives = negatives
        self.frameOffsets = frameOffsets
        self.strokes = strokes
        self.caption = caption
        self.showsDate = showsDate
        self.blotches = blotches
        self.developed = developed
        self.printFile = printFile
        self.desk = desk
        self.tornFrom = tornFrom
    }

    public var layout: PaperLayout { format.layout }

    /// 日期题字：「2026/11/23」。
    public var dateText: String {
        PhotoRecord.dateFormatter.string(from: createdAt)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// 每格的随机错位（大头贴机）。
    public static func makeFrameOffsets(count: Int, seed: UInt64, amount: Double) -> [FrameOffset] {
        var rng = SeededRandom(seed: seed ^ 0x0FF5E7)
        return (0..<count).map { _ in
            FrameOffset(dx: rng.signed() * amount, dy: rng.signed() * amount)
        }
    }

    /// 桌面上的随机倾斜角度。
    public static func randomTilt(seed: UInt64) -> Double {
        var rng = SeededRandom(seed: seed ^ 0x7117)
        return rng.signed() * 4.5
    }
}
