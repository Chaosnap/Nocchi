import CoreGraphics
import Foundation

/// Blender 渲染的相框图层（`design/blender/frames/`，输出在 `Resources/Frames/`）。
///
/// 每款相框两张图，和成片同一个分辨率（20 px/mm）：`-base`（照片下面：卡纸、蕾丝边）和 `-overlay`（照片上面：
/// 心环、烫金线、缎带蝴蝶结、阴影，其余透明）。屏幕上的相纸和导出的成片都走 `TemplateArt`，所以两边一样。
/// 图不在（比如旧版本的包）时返回 nil，调用方退回程序化画法。
public enum FrameLayers {
    public enum Kind: String, Sendable {
        case base
        case overlay
    }

    private static let lock = NSLock()
    private static var cache: [String: CGImage] = [:]

    /// 情人节相框（`booth-heart`）在这个规格上的图层；只有四格条和四宫格有。`size` 是相纸的像素大小。
    public static func valentine(_ kind: Kind, layout: PaperLayout, size: CGSize) -> CGImage? {
        let format: String
        if layout == .boothStrip {
            format = "strip"
        } else if layout == .boothGrid {
            format = "grid"
        } else {
            return nil
        }
        return image("valentine-\(format)-\(kind.rawValue)", ext: kind == .base ? "jpg" : "png", longEdge: max(size.width, size.height))
    }

    /// 读一张图层，按需要的长边缩小（按 256 像素一档缓存，缩略图不放大）。
    static func image(_ name: String, ext: String, longEdge: CGFloat) -> CGImage? {
        let bucket = max(256, Int((longEdge / 256).rounded(.up)) * 256)
        let key = "\(name).\(ext)@\(bucket)"
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        guard let url = Bundle.module.url(forResource: name, withExtension: ext)
            ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Frames"),
            let image = ImageIOKit.load(url, maxPixel: bucket) else { return nil }
        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }
}
