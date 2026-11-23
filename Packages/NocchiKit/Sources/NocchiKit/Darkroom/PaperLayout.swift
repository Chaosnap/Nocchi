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

    /// 横幅照片（一次性相机、日期机）。
    public static let landscape = PaperLayout(
        paperSize: CGSize(width: 102, height: 76),
        windows: [CGRect(x: 4, y: 4, width: 94, height: 62.67)],
        captionArea: CGRect(x: 5, y: 67.5, width: 92, height: 7.5),
        cornerRadius: 1.0
    )
}

/// 画幅。
public enum FilmFormat: String, Codable, CaseIterable, Sendable {
    case instantSquare
    case boothStrip
    case landscape

    public var layout: PaperLayout {
        switch self {
        case .instantSquare: return .instantSquare
        case .boothStrip: return .boothStrip
        case .landscape: return .landscape
        }
    }

    /// 屏幕上默认显示宽度（点）。
    public var defaultDisplayWidth: CGFloat {
        switch self {
        case .instantSquare: return 232
        case .boothStrip: return 132
        case .landscape: return 300
        }
    }

    /// 导出成片的像素宽度。
    public var printPixelWidth: Int {
        switch self {
        case .instantSquare: return 1760
        case .boothStrip: return 1040
        case .landscape: return 2040
        }
    }
}
