import CoreGraphics
import Foundation
import Vision

/// 把任意比例的截图 / 照片裁成相纸窗口的比例。
public enum CropMath {
    /// 在 `imageSize` 内取一个 `aspect`（宽 / 高）的最大矩形，尽量以 `focus` 为中心。
    ///
    /// `focus` 为归一化坐标，原点在左下（与 Core Image、Vision 一致）。返回像素坐标。
    public static func cropRect(imageSize: CGSize, aspect: CGFloat, focus: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CGRect {
        let w = imageSize.width, h = imageSize.height
        guard w >= 1, h >= 1, aspect > 0, aspect.isFinite else {
            return CGRect(origin: .zero, size: imageSize)
        }
        var cw = w
        var ch = w / aspect
        if ch > h {
            ch = h
            cw = h * aspect
        }
        cw = max(1, floor(cw))
        ch = max(1, floor(ch))
        let fx = min(max(focus.x, 0), 1)
        let fy = min(max(focus.y, 0), 1)
        let x = min(max(fx * w - cw / 2, 0), w - cw)
        let y = min(max(fy * h - ch / 2, 0), h - ch)
        return CGRect(x: floor(x), y: floor(y), width: cw, height: ch)
    }
}

/// 用 Vision 的显著性检测找到画面重点，裁剪时尽量把它留在相纸窗口里。
public enum SmartCrop {
    /// 返回归一化焦点（原点左下）。检测失败时返回画面中心。
    public static func focusPoint(in image: CGImage) -> CGPoint {
        let center = CGPoint(x: 0.5, y: 0.5)
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return center
        }
        guard let observation = request.results?.first,
              let objects = observation.salientObjects, !objects.isEmpty else {
            return center
        }
        var union = objects[0].boundingBox
        for object in objects.dropFirst() {
            union = union.union(object.boundingBox)
        }
        // 偏向中心一点，避免裁得太偏。
        let x = union.midX * 0.75 + 0.5 * 0.25
        let y = union.midY * 0.75 + 0.5 * 0.25
        return CGPoint(x: x, y: y)
    }
}
