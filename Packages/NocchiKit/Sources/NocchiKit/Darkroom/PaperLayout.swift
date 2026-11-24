import CoreGraphics
import Foundation

/// 相纸版式。尺寸以毫米为单位（只有比例有意义），原点在相纸左上角。
public struct PaperLayout: Equatable, Sendable {
    public var paperSize: CGSize
    /// 图像窗口。
    public var windows: [CGRect]
    /// 白边上的书写区。
    public var captionArea: CGRect
    public var cornerRadius: CGFloat

    public init(paperSize: CGSize, windows: [CGRect], captionArea: CGRect, cornerRadius: CGFloat) {
        self.paperSize = paperSize
        self.windows = windows
        self.captionArea = captionArea
        self.cornerRadius = cornerRadius
    }

    /// 相纸宽高比。
    public var aspect: CGFloat { paperSize.width / paperSize.height }

    /// 图像窗口宽高比（各窗口相同）。
    public var windowAspect: CGFloat {
        guard let first = windows.first, first.height > 0 else { return 1 }
        return first.width / first.height
    }

    /// 给定相纸宽度（点或像素）时的相纸尺寸。
    public func size(forWidth width: CGFloat) -> CGSize {
        CGSize(width: width, height: width / aspect)
    }

    /// 把毫米矩形换算到宽度为 `width` 的相纸上。
    public func scaled(_ rect: CGRect, toWidth width: CGFloat) -> CGRect {
        let s = width / paperSize.width
        return CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s)
    }

    /// 归一化（0…1，相对相纸宽和高）。
    public func normalized(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX / paperSize.width,
            y: rect.minY / paperSize.height,
            width: rect.width / paperSize.width,
            height: rect.height / paperSize.height
        )
    }

    /// 方形即显相纸（厚底边，可以写字）。
    public static let instantSquare = PaperLayout(
        paperSize: CGSize(width: 88, height: 107),
        windows: [CGRect(x: 4.5, y: 5.5, width: 79, height: 79)],
        captionArea: CGRect(x: 6, y: 87, width: 76, height: 17.5),
        cornerRadius: 1.6
    )

    /// 大头贴四格竖条。
    public static let boothStrip = PaperLayout(
        paperSize: CGSize(width: 52, height: 160),
        windows: [
            CGRect(x: 4, y: 4, width: 44, height: 33),
            CGRect(x: 4, y: 40, width: 44, height: 33),
            CGRect(x: 4, y: 76, width: 44, height: 33),
            CGRect(x: 4, y: 112, width: 44, height: 33)
        ],
        captionArea: CGRect(x: 4, y: 147, width: 44, height: 11),
        cornerRadius: 1.2
    )

    /// 迷你即显相纸（竖幅卡片大小，54 × 86：窄白边、厚底边）。
    public static let instantMini = PaperLayout(
        paperSize: CGSize(width: 54, height: 86),
        windows: [CGRect(x: 4, y: 6.5, width: 46, height: 62)],
        captionArea: CGRect(x: 5, y: 70.5, width: 44, height: 14),
        cornerRadius: 2.6
    )

    /// 宽幅即显相纸（108 × 86：横向画面、厚底边）。
    public static let instantWide = PaperLayout(
        paperSize: CGSize(width: 108, height: 86),
        windows: [CGRect(x: 4.5, y: 6.5, width: 99, height: 62)],
        captionArea: CGRect(x: 6, y: 70.5, width: 96, height: 14),
        cornerRadius: 2.4
    )

    /// 四宫格大头贴（4 × 6 英寸竖版，2 × 2 个 3:4 画面）。
    public static let boothGrid = PaperLayout(
        paperSize: CGSize(width: 102, height: 152),
        windows: [
            CGRect(x: 4, y: 5, width: 45, height: 60),
            CGRect(x: 53, y: 5, width: 45, height: 60),
            CGRect(x: 4, y: 69, width: 45, height: 60),
            CGRect(x: 53, y: 69, width: 45, height: 60)
        ],
        captionArea: CGRect(x: 5, y: 133, width: 92, height: 15),
        cornerRadius: 1.0
    )

    /// 横幅照片（一次性相机、日期机）。
    public static let landscape = PaperLayout(
        paperSize: CGSize(width: 102, height: 76),
        windows: [CGRect(x: 4, y: 4, width: 94, height: 62.67)],
        captionArea: CGRect(x: 5, y: 67.5, width: 92, height: 7.5),
        cornerRadius: 1.0
    )
}

/// 画幅（相纸规格）。即显相机可以在方形 / 迷你 / 宽幅 / 冲印小照之间选；大头贴机可以选四格条或四宫格。
public enum FilmFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 方形即显（88 × 107，方形画面）。
    case instantSquare
    /// 四格大头贴竖条。
    case boothStrip
    /// 冲印小照（白边 3:2 横幅，老相馆的冲印小照）。
    case landscape
    /// 迷你即显（54 × 86，竖幅画面）。
    case instantMini
    /// 宽幅即显（108 × 86，横幅画面）。
    case instantWide
    /// 四宫格大头贴（2 × 2）。
    case boothGrid

    public var id: String { rawValue }

    public var layout: PaperLayout {
        switch self {
        case .instantSquare: return .instantSquare
        case .boothStrip: return .boothStrip
        case .landscape: return .landscape
        case .instantMini: return .instantMini
        case .instantWide: return .instantWide
        case .boothGrid: return .boothGrid
        }
    }

    /// 中文名。
    public var displayName: String {
        switch self {
        case .instantSquare: return "方形即显"
        case .instantMini: return "迷你即显"
        case .instantWide: return "宽幅即显"
        case .landscape: return "冲印小照"
        case .boothStrip: return "四格条"
        case .boothGrid: return "四宫格"
        }
    }

    /// 一句话规格说明。
    public var note: String {
        switch self {
        case .instantSquare: return "88×107 · 方形画面 · 厚底边可以写字"
        case .instantMini: return "54×86 · 竖幅小卡 · 能放进钱包"
        case .instantWide: return "108×86 · 横幅画面 · 适合合照与风景"
        case .landscape: return "102×76 · 3:2 白边冲印小照"
        case .boothStrip: return "52×160 · 四格竖条"
        case .boothGrid: return "102×152 · 2×2 四宫格"
        }
    }

    /// 即显相纸（有药包隆起、厚底边）。
    public var isInstant: Bool {
        switch self {
        case .instantSquare, .instantMini, .instantWide: return true
        default: return false
        }
    }

    /// 大头贴版式（一次拍 4 格）。
    public var isBooth: Bool {
        self == .boothStrip || self == .boothGrid
    }

    /// 一张相纸上的画面数。
    public var frameCount: Int { layout.windows.count }

    /// 即显相机可选的相纸。
    public static let instantChoices: [FilmFormat] = [.instantSquare, .instantMini, .instantWide, .landscape]
    /// 大头贴机可选的相纸。
    public static let boothChoices: [FilmFormat] = [.boothStrip, .boothGrid]

    /// 屏幕上默认显示宽度（点）。
    public var defaultDisplayWidth: CGFloat {
        switch self {
        case .instantSquare: return 232
        case .boothStrip: return 132
        case .landscape: return 300
        case .instantMini: return 168
        case .instantWide: return 330
        case .boothGrid: return 236
        }
    }

    /// 导出成片的像素宽度。
    public var printPixelWidth: Int {
        switch self {
        case .instantSquare: return 1760
        case .boothStrip: return 1040
        case .landscape: return 2040
        case .instantMini: return 1080
        case .instantWide: return 2160
        case .boothGrid: return 2040
        }
    }
}
