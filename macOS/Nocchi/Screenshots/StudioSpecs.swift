import CoreGraphics
import Foundation
import NocchiKit

/// 截图用的一张样片：用哪张原创样片、什么胶卷 / 相纸 / 模板、题字、标签、地点、几天前拍的、贴纸和笔迹。
struct StudioSpec {
    var key: String
    var sample: String
    var stockID: String
    var format: FilmFormat
    var templateID: String
    var caption: String?
    var font: CaptionFont = .handwriting
    var tags: [String] = []
    var location: String?
    var daysAgo: Int
    var minute: Int = 600
    var stickers: [StickerPlacement] = []
    var strokes: [InkStroke] = []
    var showsTagStickers = true
}

/// 截图工作室冲印的一批照片（日期相对于今天，所以相册、挂历每个月都有内容）。
enum StudioSpecs {
    static var all: [StudioSpec] {
        [
            StudioSpec(
                key: "latte", sample: "latte", stockID: "cream-600", format: .instantSquare, templateID: "classic",
                caption: "早安，拿铁", tags: ["咖啡", "早晨"], location: "上海", daysAgo: 0, minute: 8 * 60 + 40,
                stickers: [
                    StickerPlacement(kindID: "tape.washi", x: 0.5, y: 0.035, size: 0.36, rotation: -4),
                    StickerPlacement(kindID: "stamp.postmark", x: 0.76, y: 0.73, size: 0.32, rotation: -14, text: postmark(daysAgo: 0)),
                    StickerPlacement(kindID: "badge.coffee", x: 0.87, y: 1.075, size: 0.15, rotation: 10)
                ],
                showsTagStickers: false
            ),
            StudioSpec(
                key: "dog", sample: "dog", stockID: "gold-200", format: .instantSquare, templateID: "seventies",
                caption: "公园里的小狗", tags: ["小狗", "阳光"], location: "人民公园", daysAgo: 1, minute: 17 * 60 + 5,
                strokes: [heart(centerX: 0.2, centerY: 0.18, size: 0.075, color: "#F4F1EA", tool: .paint)]
            ),
            StudioSpec(
                key: "cat", sample: "cat", stockID: "portrait-400", format: .instantMini, templateID: "deckle",
                caption: "午后的猫", font: .typewriter, tags: ["猫咪"], daysAgo: 2, minute: 14 * 60 + 30
            ),
            StudioSpec(
                key: "booth-strip", sample: "booth-grid", stockID: "booth-flash-400", format: .boothStrip, templateID: "booth-classic",
                caption: "我们", daysAgo: 2, minute: 19 * 60 + 12
            ),
            StudioSpec(
                key: "street", sample: "street", stockID: "night-flight-800", format: .instantWide, templateID: "filmframe",
                caption: "雨夜小巷", tags: ["夜晚", "旅行"], location: "京都", daysAgo: 2, minute: 20 * 60 + 45
            ),
            StudioSpec(
                key: "beach", sample: "beach", stockID: "sunset-200", format: .landscape, templateID: "datebook",
                caption: "海边的日落", tags: ["旅行"], location: "厦门", daysAgo: 6, minute: 18 * 60 + 20
            ),
            StudioSpec(
                key: "booth-heart", sample: "booth-grid", stockID: "booth-flash-400", format: .boothGrid, templateID: "booth-heart",
                caption: "情人节快乐", daysAgo: 8, minute: 15 * 60
            ),
            StudioSpec(
                key: "blossom", sample: "blossom", stockID: "mint-400", format: .instantSquare, templateID: "postage",
                caption: "春天来信", font: .serif, daysAgo: 9, minute: 11 * 60 + 15
            ),
            StudioSpec(
                key: "bike", sample: "bike", stockID: "lemon-soda-100", format: .instantMini, templateID: "kraft",
                caption: "黄墙下的单车", daysAgo: 12, minute: 13 * 60 + 40
            ),
            StudioSpec(
                key: "sparklers", sample: "sparklers", stockID: "tungsten-800", format: .instantSquare, templateID: "noir",
                caption: "新年快乐", tags: ["朋友", "夜晚"], daysAgo: 15, minute: 23 * 60 + 50
            ),
            StudioSpec(
                key: "tulips", sample: "tulips", stockID: "silver-400", format: .instantSquare, templateID: "album",
                caption: "郁金香", font: .serif, daysAgo: 19, minute: 10 * 60
            ),
            StudioSpec(
                key: "lake", sample: "lake", stockID: "evergreen-400", format: .landscape, templateID: "classic",
                caption: "清晨的湖", location: "千岛湖", daysAgo: 24, minute: 6 * 60 + 30
            ),
            StudioSpec(
                key: "booth-noir", sample: "booth-grid", stockID: "booth-silver-400", format: .boothStrip, templateID: "booth-noir",
                caption: "老照相亭", daysAgo: 31, minute: 16 * 60 + 10
            )
        ]
    }

    /// 冲印一张：底片 → 照片库，合成成片 → 照片库，保存记录。在后台线程调用。
    static func develop(_ spec: StudioSpec, frames: [CGImage], library: PhotoLibrary, processor: FilmProcessor, now: Date) -> StudioPrint? {
        let stock = FilmCatalog.stock(id: spec.stockID)
        let body: CameraBody = spec.format.isBooth ? .photoBooth : .instant
        let seed = stableSeed(spec.key)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: -spec.daysAgo, to: startOfToday) ?? now
        let date = calendar.date(byAdding: .minute, value: spec.minute, to: day) ?? day

        var record = PhotoRecord(
            createdAt: date,
            source: spec.format.isBooth ? .booth : .library,
            body: body,
            stock: stock,
            seed: seed,
            showsDate: true
        )
        record.format = spec.format
        record.templateID = spec.templateID
        record.caption = spec.caption
        record.captionFont = spec.font
        record.tags = spec.tags
        record.location = spec.location
        record.stickers = spec.stickers
        record.strokes = spec.strokes
        record.showsTagStickers = spec.showsTagStickers
        record.developed = true
        if spec.format.isBooth {
            record.frameOffsets = PhotoRecord.makeFrameOffsets(count: frames.count, seed: seed, amount: 0.012)
        }

        var negatives: [CGImage] = []
        var names: [String] = []
        for (index, frame) in frames.enumerated() {
            let options = ProcessOptions(
                targetAspect: spec.format.layout.windowAspect,
                focus: SmartCrop.focusPoint(in: frame),
                maxLongEdge: 1400,
                mirror: false,
                seed: seed &+ UInt64(index),
                exposureBias: body.exposureBias
            )
            guard let negative = processor.process(frame, stock: stock, options: options) else { return nil }
            negatives.append(negative)
            if let name = try? library.writeNegative(negative, recordID: record.id, index: index) {
                names.append(name)
            }
        }
        record.negatives = names
        let printSpec = PrintSpec(record: record, stockPaper: stock.paper, images: negatives, widthPixels: record.format.printPixelWidth)
        if let image = PhotoComposer.render(printSpec), let relative = try? library.writePrint(image, for: record) {
            record.printFile = relative
        }
        try? library.save(record)
        return StudioPrint(record: record, images: negatives, paper: stock.paper)
    }

    /// 由名字推出的固定种子（FNV-1a，每次运行都一样）。
    static func stableSeed(_ key: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash & ((1 << 52) - 1)
    }

    /// 邮戳上的日期（「NOCCHI · 2026.11.24」）。
    static func postmark(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return "NOCCHI · " + formatter.string(from: date)
    }

    /// 一颗手画的心（相纸宽度单位，原点左上）。
    static func heart(centerX: Double, centerY: Double, size: Double, color: String, tool: InkTool) -> InkStroke {
        var points: [InkPoint] = []
        let steps = 56
        for step in 0...steps {
            let t = Double(step) / Double(steps) * 2 * Double.pi
            let sine = Foundation.sin(t)
            let x = 16 * sine * sine * sine
            let y = 13 * Foundation.cos(t) - 5 * Foundation.cos(2 * t) - 2 * Foundation.cos(3 * t) - Foundation.cos(4 * t)
            let pressure = 0.0065 + 0.0015 * Foundation.sin(t * 3)
            points.append(InkPoint(x: centerX + x / 16 * size, y: centerY - y / 16 * size, w: pressure))
        }
        return InkStroke(points: points, color: color, tool: tool)
    }
}
