import CoreGraphics
import Foundation
import XCTest
@testable import NocchiKit

final class CustomStickerTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("nocchi-stickers-\(UUID().uuidString)")
    }

    override func tearDown() {
        StickerArt.customProvider = nil
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// 200 × 100 的透明图，中间一块 100 × 50 的红色。
    private func sampleImageURL() throws -> URL {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try XCTUnwrap(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(srgbRed: 0.8, green: 0.2, blue: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 50, y: 25, width: 100, height: 50))
        let image = try XCTUnwrap(ctx.makeImage())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.png")
        try ImageIOKit.writePNG(image, to: url)
        return url
    }

    func testImportTrimsTransparentMarginsAndPersists() throws {
        let store = CustomStickerStore(directory: directory.appendingPathComponent("stickers"))
        let sticker = try store.importImage(at: try sampleImageURL(), name: "红块")
        XCTAssertEqual(sticker.name, "红块")
        XCTAssertEqual(sticker.aspect, 104.0 / 54.0, accuracy: 0.05)
        XCTAssertTrue(sticker.kindID.hasPrefix(CustomStickerStore.prefix))
        XCTAssertEqual(CustomStickerStore.id(fromKindID: sticker.kindID), sticker.id)

        let reopened = CustomStickerStore(directory: directory.appendingPathComponent("stickers"))
        XCTAssertEqual(reopened.stickers.map(\.id), [sticker.id])
        let art = try XCTUnwrap(reopened.art(forKindID: sticker.kindID))
        XCTAssertEqual(Double(art.image.width), 104, accuracy: 2)
    }

    func testRenameMoveDieCutAndRemove() throws {
        let store = CustomStickerStore(directory: directory.appendingPathComponent("stickers"))
        let url = try sampleImageURL()
        let a = try store.importImage(at: url, name: "A")
        let b = try store.importImage(at: url, name: "B")
        store.move(b.id, by: -1)
        XCTAssertEqual(store.stickers.map(\.name), ["B", "A"])
        store.rename(a.id, to: "  新名字  ")
        XCTAssertEqual(store.sticker(id: a.id)?.name, "新名字")
        store.setDieCut(a.id, false)
        XCTAssertEqual(store.sticker(id: a.id)?.dieCut, false)
        store.remove(a.id)
        XCTAssertEqual(store.stickers.map(\.id), [b.id])
        // 删掉的贴纸已经贴在照片上的，照样画得出来。
        XCTAssertNotNil(store.art(forKindID: a.kindID))
    }

    func testStickerArtDrawsCustomStickersThroughTheProvider() throws {
        let store = CustomStickerStore(directory: directory.appendingPathComponent("stickers"))
        let sticker = try store.importImage(at: try sampleImageURL(), name: "红块")
        let placement = StickerPlacement(kindID: sticker.kindID, x: 0.5, y: 0.5, size: 0.4)
        XCTAssertNil(StickerArt.image(for: placement, pixelWidth: 120), "no provider, nothing to draw")

        StickerArt.customProvider = { store.art(forKindID: $0) }
        let image = try XCTUnwrap(StickerArt.image(for: placement, pixelWidth: 240))
        XCTAssertEqual(Double(image.width) / Double(image.height), sticker.aspect, accuracy: 0.05)
        let frame = StickerArt.frame(of: placement, paperWidth: 500)
        XCTAssertEqual(Double(frame.width / frame.height), sticker.aspect, accuracy: 0.01)

        var spec = PrintSpec(layout: .instantSquare, paper: .classic, images: [], widthPixels: 300)
        let plain = PixelBuffer(try XCTUnwrap(PhotoComposer.renderOverlay(spec)))
        spec.stickers = [placement]
        let decorated = PixelBuffer(try XCTUnwrap(PhotoComposer.renderOverlay(spec)))
        XCTAssertNotEqual(plain.bytes, decorated.bytes)
    }
}
