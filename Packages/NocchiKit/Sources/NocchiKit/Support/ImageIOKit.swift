import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO 读写小工具（两个平台通用，不依赖 AppKit / UIKit）。
public enum ImageIOKit {
    public enum WriteError: Error {
        case cannotCreateDestination
        case finalizeFailed
    }

    /// 读取图片并应用 EXIF 方向；可选限制长边像素。
    public static func load(_ url: URL, maxPixel: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return image(from: source, maxPixel: maxPixel)
    }

    public static func load(data: Data, maxPixel: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return image(from: source, maxPixel: maxPixel)
    }

    private static func image(from source: CGImageSource, maxPixel: Int?) -> CGImage? {
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let maxPixel {
            options[kCGImageSourceThumbnailMaxPixelSize] = maxPixel
        } else if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 4096
            let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 4096
            options[kCGImageSourceThumbnailMaxPixelSize] = max(w, h)
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func jpegData(_ image: CGImage, quality: Double = 0.92) -> Data? {
        encode(image, type: .jpeg, quality: quality)
    }

    public static func pngData(_ image: CGImage) -> Data? {
        encode(image, type: .png, quality: nil)
    }

    public static func encode(_ image: CGImage, type: UTType, quality: Double?) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil) else {
            return nil
        }
        var props: [CFString: Any] = [:]
        if let quality {
            props[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// 写 JPEG 文件（原子写入）。
    public static func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.92) throws {
        guard let data = jpegData(image, quality: quality) else { throw WriteError.finalizeFailed }
        try data.write(to: url, options: .atomic)
    }

    /// 写 PNG 文件（原子写入）。
    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = pngData(image) else { throw WriteError.finalizeFailed }
        try data.write(to: url, options: .atomic)
    }
}
