import CoreGraphics
import CoreImage
import Foundation
import Metal
@testable import NocchiKit

enum TestImages {
    /// 一张带渐变和色块的测试图：左红右蓝、上亮下暗，中间一块白色高光。
    static func gradient(width: Int = 320, height: Int = 200) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for x in 0..<width {
            for band in 0..<4 {
                let u = CGFloat(x) / CGFloat(width - 1)
                let v = CGFloat(band) / 3
                ctx.setFillColor(CGColor(srgbRed: 1 - u, green: 0.3 + 0.4 * v, blue: u, alpha: 1))
                ctx.fill(CGRect(x: x, y: band * height / 4, width: 1, height: height / 4 + 1))
            }
        }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: width / 2 - 20, y: height / 2 - 20, width: 40, height: 40))
        return ctx.makeImage()!
    }

    static func solid(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, width: Int = 64, height: Int = 64) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}

/// 把 CGImage 读成 RGBA8 像素，方便断言。
struct PixelBuffer {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        let w = image.width
        let h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        data.withUnsafeMutableBytes { raw in
            let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        width = w
        height = h
        bytes = data
    }

    /// (x, y) 以左上为原点。
    func rgb(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        let i = (y * width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }

    /// 全图平均通道差（判断是不是灰度图）。
    var meanChannelSpread: Double {
        var total = 0
        var count = 0
        var i = 0
        while i < bytes.count {
            let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
            total += max(r, g, b) - min(r, g, b)
            count += 1
            i += 4
        }
        return count == 0 ? 0 : Double(total) / Double(count)
    }

    func meanAbsoluteDifference(_ other: PixelBuffer) -> Double {
        guard other.bytes.count == bytes.count else { return .infinity }
        var total = 0
        for i in 0..<bytes.count where i % 4 != 3 {
            total += abs(Int(bytes[i]) - Int(other.bytes[i]))
        }
        return Double(total) / Double(bytes.count / 4 * 3)
    }
}

enum TestContext {
    /// CI 虚拟机可能没有 Metal，这时退回软件渲染。
    static let processor: FilmProcessor = {
        let software = MTLCreateSystemDefaultDevice() == nil
        return FilmProcessor(context: FilmProcessor.makeContext(softwareRenderer: software))
    }()
}

func temporaryDirectory(_ name: String = UUID().uuidString) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("NocchiKitTests-\(name)", isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
