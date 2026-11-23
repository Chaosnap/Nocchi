import CoreGraphics
import Foundation

/// Mac 刘海的位置（AppKit 全局屏幕坐标，原点在左下）。
public struct NotchMetrics: Equatable, Sendable {
    public var rect: CGRect
    /// true：真实的硬件刘海；false：为没有刘海的屏幕画的虚拟刘海。
    public var isHardware: Bool

    public init(rect: CGRect, isHardware: Bool) {
        self.rect = rect
        self.isHardware = isHardware
    }

    /// 由 `NSScreen` 的数据计算刘海矩形。
    ///
    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`（有刘海时 > 0）
    ///   - leftAreaWidth / rightAreaWidth: `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 的宽度
    ///   - menuBarHeight: 菜单栏高度（没有刘海时虚拟刘海用它做高度）
    public static func compute(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?,
        menuBarHeight: CGFloat,
        virtualWidth: CGFloat = 196
    ) -> NotchMetrics {
        if safeAreaTop > 0, let left = leftAreaWidth, let right = rightAreaWidth {
            let width = screenFrame.width - left - right
            if width > 40, width < screenFrame.width * 0.5 {
                let rect = CGRect(x: screenFrame.minX + left, y: screenFrame.maxY - safeAreaTop, width: width, height: safeAreaTop)
                return NotchMetrics(rect: rect, isHardware: true)
            }
        }
        let height = max(menuBarHeight, 24)
        let rect = CGRect(x: screenFrame.midX - virtualWidth / 2, y: screenFrame.maxY - height, width: virtualWidth, height: height)
        return NotchMetrics(rect: rect, isHardware: false)
    }

    /// 鼠标悬停热区：刘海本身，左右各放宽一点、向下多给几个点。
    public var hoverZone: CGRect {
        CGRect(x: rect.minX - 14, y: rect.minY - 8, width: rect.width + 28, height: rect.height + 8)
    }
}

/// iPhone 灵动岛的位置（UIKit 坐标，原点左上，单位点）。
///
/// 系统没有公开灵动岛的几何信息，这里按顶部安全区高度估算：
/// - 安全区 ≥ 58pt：灵动岛机型（14 Pro 及之后），岛约 126 × 37pt，顶端距屏幕约 安全区 − 48pt；
/// - 43…57pt：刘海机型，用一个贴着刘海下沿的虚拟「出片口」；
/// - 其他：无刘海机型，出片口放在状态栏下面。
public struct IslandMetrics: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case dynamicIsland
        case notch
        case none
    }

    public var rect: CGRect
    public var kind: Kind

    public init(rect: CGRect, kind: Kind) {
        self.rect = rect
        self.kind = kind
    }

    public static func estimate(screenWidth: CGFloat, safeAreaTop: CGFloat) -> IslandMetrics {
        if safeAreaTop >= 58 {
            let size = CGSize(width: 126, height: 37.33)
            let top = max(8, safeAreaTop - 48)
            return IslandMetrics(rect: CGRect(x: (screenWidth - size.width) / 2, y: top, width: size.width, height: size.height), kind: .dynamicIsland)
        }
        if safeAreaTop >= 43 {
            let size = CGSize(width: 132, height: 30)
            return IslandMetrics(rect: CGRect(x: (screenWidth - size.width) / 2, y: 4, width: size.width, height: size.height), kind: .notch)
        }
        let size = CGSize(width: 120, height: 28)
        return IslandMetrics(rect: CGRect(x: (screenWidth - size.width) / 2, y: max(safeAreaTop, 20) + 4, width: size.width, height: size.height), kind: .none)
    }

    /// 出片时岛「张开」成的出片口：比相纸宽一点、比岛高一点。
    public func slotRect(paperWidth: CGFloat) -> CGRect {
        let width = max(rect.width, paperWidth + 26)
        let height = rect.height + 10
        return CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: height)
    }
}
