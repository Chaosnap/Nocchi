import Foundation

/// 相机柜里的机身。出片口始终是刘海（Mac）或灵动岛（iPhone）。
public enum CameraBody: String, Codable, CaseIterable, Identifiable, Sendable {
    case instant
    case photoBooth
    case disposable
    case dateStamp
    case halfFrame
    case twinLens
    case pinhole
    case wiggle

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .instant: return String(localized: "即显相机")
        case .photoBooth: return String(localized: "大头贴机")
        case .disposable: return String(localized: "一次性相机")
        case .dateStamp: return String(localized: "日期机")
        case .halfFrame: return String(localized: "半格相机")
        case .twinLens: return String(localized: "双反相机")
        case .pinhole: return String(localized: "针孔相机")
        case .wiggle: return String(localized: "摇摆 3D 相机")
        }
    }

    public var tagline: String {
        switch self {
        case .instant: return String(localized: "一张一出，甩一甩加速显影，白边可以写字")
        case .photoBooth: return String(localized: "拉帘、倒数、闪光、四连拍")
        case .disposable: return String(localized: "一卷 27 张，拍完前不能看，第二天早上冲好")
        case .dateStamp: return String(localized: "右下角印上橙色日期，年份可以调成 1998")
        case .halfFrame: return String(localized: "连拍两张，自动拼成一对")
        case .twinLens: return String(localized: "磨砂玻璃取景，画面左右颠倒")
        case .pinhole: return String(localized: "曝光 5 秒，一动就有重影")
        case .wiggle: return String(localized: "四张合成左右晃动的立体 GIF")
        }
    }

    /// SF Symbol 兜底图标。
    public var symbolName: String {
        switch self {
        case .instant: return "camera.fill"
        case .photoBooth: return "person.crop.rectangle.stack.fill"
        case .disposable: return "camera.on.rectangle"
        case .dateStamp: return "calendar"
        case .halfFrame: return "rectangle.split.2x1"
        case .twinLens: return "camera.metering.center.weighted"
        case .pinhole: return "circle.dashed"
        case .wiggle: return "square.stack.3d.forward.dottedline"
        }
    }

    /// 当前版本可用（其余在路线图里）。
    public var isAvailable: Bool {
        switch self {
        case .instant, .photoBooth: return true
        default: return false
        }
    }

    public var format: FilmFormat {
        switch self {
        case .photoBooth: return .boothStrip
        case .disposable, .dateStamp, .halfFrame: return .landscape
        default: return .instantSquare
        }
    }

    /// 一次快门拍几格。
    public var framesPerShot: Int {
        switch self {
        case .photoBooth: return 4
        case .halfFrame: return 2
        case .wiggle: return 4
        default: return 1
        }
    }

    /// 推荐胶卷。
    public var defaultStockID: String {
        switch self {
        case .photoBooth: return "booth-flash-400"
        case .disposable: return "warm-sun-400"
        case .dateStamp: return "old-album-100"
        default: return "cream-600"
        }
    }

    /// 额外曝光：大头贴机的闪光会让脸亮一点。
    public var exposureBias: Float {
        switch self {
        case .photoBooth: return 0.2
        default: return 0
        }
    }

    /// 每一格从相纸出口出来之后的显影时长（秒，不甩的情况下）。
    public var developDuration: TimeInterval {
        switch self {
        case .photoBooth: return 9
        default: return 15
        }
    }

    /// 出片时长（马达把相纸推出来的时间）。
    public var ejectDuration: TimeInterval {
        switch self {
        case .photoBooth: return 3.4
        default: return 2.2
        }
    }
}
