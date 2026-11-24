import Combine
import CoreGraphics
import Foundation
import NocchiKit
import SceneKit
import simd

#if canImport(UIKit)
import UIKit
typealias SceneColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias SceneColor = NSColor
#endif

/// 3D 照片卡片盒：木头抽屉里按 A–Z 立着的相片卡，抽出来平放在桌上叠成一堆，再放回去。
///
/// 每张相片是一个「holder」节点（位置 + 偏航）带一个「card」子节点（俯仰：立着 / 平放），
/// 这样抽出、翻转、落下可以分开做动画。
@MainActor
public final class CardBoxScene: ObservableObject {
    public let scene = SCNScene()
    private let gestures = SceneGestureTarget()

    private enum Placement: Equatable {
        case drawer(Int)
        case pile(Int)
    }

    private let world = SCNNode()
    private let cameraNode = SCNNode()
    private let boxNode = SCNNode()
    private var holders: [UUID: SCNNode] = [:]
    private var cards: [UUID: SCNNode] = [:]
    private var fronts: [UUID: SCNMaterial] = [:]
    private var placements: [UUID: Placement] = [:]
    private var appliedImages = Set<UUID>()
    private var dividers: [String: SCNNode] = [:]
    private weak var model: CardBoxModel?
    private var cancellables = Set<AnyCancellable>()
    private(set) var isWide = true

    // 尺寸（米）。
    private let boxLength: Float = 0.30
    private let boxWidth: Float = 0.176
    private let boxHeight: Float = 0.086
    private let wall: Float = 0.008
    private let cardThickness: Float = 0.0009
    private let lean: Float = -0.1
    private let dividerHeight: Float = 0.104
    private var boxCenter = SIMD3<Float>(-0.16, 0, -0.01)
    private var boxYaw: Float = 0.32
    private var pileCenter = SIMD3<Float>(0.15, 0, 0.04)

    /// 木纹：优先用 Codex 生成的胡桃木素材（App 资源里的 WoodTexture），没有时退回程序生成。
    private lazy var woodImage: Any? = {
        #if canImport(UIKit)
        if let image = UIImage(named: "WoodTexture") { return image }
        #elseif canImport(AppKit)
        if let image = NSImage(named: "WoodTexture") { return image }
        #endif
        return ProceduralTextures.wood()
    }()
    private lazy var paperMaterial = material(color: SceneColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1), roughness: 0.78)
    private lazy var dividerMaterial = material(color: SceneColor(red: 0.90, green: 0.84, blue: 0.70, alpha: 1), roughness: 0.86)

    public init() {
        buildScene()
        gestures.onHit = { [weak self] point, view, double in
            MainActor.assumeIsolated {
                self?.hit(at: point, in: view, double: double)
            }
        }
    }

    // MARK: - Model binding

    public func attach(_ model: CardBoxModel) {
        guard self.model !== model else { return }
        self.model = model
        cancellables.removeAll()
        model.$records.combineLatest(model.$pulled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] records, pulled in
                MainActor.assumeIsolated {
                    self?.sync(records: records, pulled: pulled, animated: true)
                }
            }
            .store(in: &cancellables)
        model.$images
            .receive(on: DispatchQueue.main)
            .sink { [weak self] images in
                MainActor.assumeIsolated {
                    self?.applyImages(images)
                }
            }
            .store(in: &cancellables)
        sync(records: model.records, pulled: model.pulled, animated: false)
    }

    /// 横屏（Mac 窗口）：抽屉在左、照片堆在右；竖屏（iPhone）：抽屉在后、照片堆在前。
    public func setWide(_ wide: Bool) {
        guard wide != isWide else { return }
        isWide = wide
        if wide {
            boxCenter = SIMD3(-0.16, 0, -0.01)
            boxYaw = 0.32
            pileCenter = SIMD3(0.15, 0, 0.04)
        } else {
            boxCenter = SIMD3(0, 0, -0.17)
            boxYaw = 0.1
            pileCenter = SIMD3(0, 0, 0.13)
        }
        boxNode.simdPosition = boxCenter
        boxNode.simdEulerAngles = SIMD3(0, boxYaw, 0)
        layoutCamera()
        placements.removeAll()
        if let model {
            sync(records: model.records, pulled: model.pulled, animated: false)
        }
    }

    // MARK: - View

    public func makeView() -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.pointOfView = cameraNode
        view.antialiasingMode = .multisampling4X
        view.isJitteringEnabled = true
        view.allowsCameraControl = false
        view.backgroundColor = SceneColor(red: 0.91, green: 0.89, blue: 0.86, alpha: 1)
        view.preferredFramesPerSecond = 60
        #if canImport(UIKit)
        let double = UITapGestureRecognizer(target: gestures, action: #selector(SceneGestureTarget.handleDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        let single = UITapGestureRecognizer(target: gestures, action: #selector(SceneGestureTarget.handleTap(_:)))
        single.require(toFail: double)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(single)
        #elseif canImport(AppKit)
        let single = NSClickGestureRecognizer(target: gestures, action: #selector(SceneGestureTarget.handleClick(_:)))
        let double = NSClickGestureRecognizer(target: gestures, action: #selector(SceneGestureTarget.handleDoubleClick(_:)))
        double.numberOfClicksRequired = 2
        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)
        #endif
        return view
    }

    private func hit(at point: CGPoint, in view: SCNView, double: Bool) {
        let results = view.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue])
        guard let node = results.first?.node, let model else { return }
        var current: SCNNode? = node
        while let candidate = current {
            if let name = candidate.name {
                if name.hasPrefix("card:"), let id = UUID(uuidString: String(name.dropFirst(5))) {
                    handleCard(id, double: double, model: model)
                    return
                }
                if name.hasPrefix("divider:") {
                    model.pull(letter: String(name.dropFirst(8)))
                    return
                }
            }
            current = candidate.parent
        }
    }

    private func handleCard(_ id: UUID, double: Bool, model: CardBoxModel) {
        guard let record = model.records.first(where: { $0.id == id }) else { return }
        if double {
            model.onOpen?(record)
            return
        }
        if model.pulled.contains(id) {
            if model.pulled.last == id {
                model.cycleTop()
            } else {
                model.bringToFront(id)
            }
        } else {
            model.pull(letter: record.indexLetter)
        }
    }

    // MARK: - Scene

    private func buildScene() {
        scene.rootNode.addChildNode(world)
        scene.lightingEnvironment.contents = ProceduralTextures.environment()
        scene.lightingEnvironment.intensity = 1.25

        let floor = SCNFloor()
        floor.reflectivity = 0
        let floorMaterial = SCNMaterial()
        floorMaterial.lightingModel = .physicallyBased
        floorMaterial.diffuse.contents = ProceduralTextures.dots()
        floorMaterial.diffuse.wrapS = .repeat
        floorMaterial.diffuse.wrapT = .repeat
        floorMaterial.diffuse.contentsTransform = textureScale(64, 64)
        floorMaterial.roughness.contents = 0.92
        floorMaterial.metalness.contents = 0.0
        floor.firstMaterial = floorMaterial
        world.addChildNode(SCNNode(geometry: floor))

        let key = SCNLight()
        key.type = .directional
        key.intensity = 950
        key.color = SceneColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1)
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowRadius = 10
        key.shadowSampleCount = 16
        key.shadowColor = SceneColor(white: 0, alpha: 0.42)
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.automaticallyAdjustsShadowProjection = true
        key.maximumShadowDistance = 2
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdEulerAngles = SIMD3(-1.0, 0.6, 0)
        world.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 260
        fill.color = SceneColor(white: 0.96, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        world.addChildNode(fillNode)

        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 20
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.1
        camera.screenSpaceAmbientOcclusionIntensity = 0.9
        camera.screenSpaceAmbientOcclusionRadius = 0.05
        camera.bloomIntensity = 0.1
        camera.bloomThreshold = 0.92
        cameraNode.camera = camera
        world.addChildNode(cameraNode)
        layoutCamera()

        buildBox()
    }

    private func layoutCamera() {
        guard let camera = cameraNode.camera else { return }
        if isWide {
            camera.projectionDirection = .vertical
            camera.fieldOfView = 30
            cameraNode.simdPosition = SIMD3(0, 0.5, 0.46)
            cameraNode.simdLook(at: SIMD3(0, 0.0, 0.01))
        } else {
            camera.projectionDirection = .horizontal
            camera.fieldOfView = 34
            cameraNode.simdPosition = SIMD3(0, 0.78, 0.5)
            cameraNode.simdLook(at: SIMD3(0, 0, -0.01))
        }
    }

    private func material(color: SceneColor, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.0
        return m
    }

    /// 贴图缩放矩阵（SceneKit 在 iOS 用 Float、在 macOS 用 CGFloat，这里统一走 simd）。
    private func textureScale(_ u: Float, _ v: Float) -> SCNMatrix4 {
        SCNMatrix4(simd_float4x4(diagonal: SIMD4<Float>(u, v, 1, 1)))
    }

    private func woodMaterial(scaleU: Float, scaleV: Float, darken: CGFloat = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = woodImage
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = textureScale(scaleU, scaleV)
        m.roughness.contents = 0.55
        m.metalness.contents = 0.0
        if darken < 1 {
            m.multiply.contents = SceneColor(white: darken, alpha: 1)
        }
        return m
    }

    private func buildBox() {
        boxNode.simdPosition = boxCenter
        boxNode.simdEulerAngles = SIMD3(0, boxYaw, 0)
        world.addChildNode(boxNode)
        let L = boxLength, W = boxWidth, H = boxHeight, t = wall

        func panel(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: SCNMaterial, chamfer: CGFloat = 0.0015) {
            let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: chamfer)
            box.materials = [material]
            let node = SCNNode(geometry: box)
            node.simdPosition = position
            boxNode.addChildNode(node)
        }

        panel(SIMD3(W, t, L), SIMD3(0, t / 2, 0), woodMaterial(scaleU: 0.6, scaleV: 1.2, darken: 0.72))
        panel(SIMD3(W, H, t), SIMD3(0, H / 2, L / 2 - t / 2), woodMaterial(scaleU: 0.7, scaleV: 0.4))
        panel(SIMD3(W, H * 1.08, t), SIMD3(0, H * 0.54, -L / 2 + t / 2), woodMaterial(scaleU: 0.7, scaleV: 0.4, darken: 0.85))
        panel(SIMD3(t, H, L - 2 * t), SIMD3(-W / 2 + t / 2, H / 2, 0), woodMaterial(scaleU: 1.2, scaleV: 0.4, darken: 0.92))
        panel(SIMD3(t, H, L - 2 * t), SIMD3(W / 2 - t / 2, H / 2, 0), woodMaterial(scaleU: 1.2, scaleV: 0.4, darken: 0.92))

        // 燕尾榫：前板两侧一列深色小块。
        let pinMaterial = woodMaterial(scaleU: 0.2, scaleV: 0.2, darken: 0.68)
        for i in 0..<4 {
            let y = H * (0.14 + 0.24 * Float(i))
            for side: Float in [-1, 1] {
                panel(SIMD3(t * 1.04, H * 0.11, t * 1.04), SIMD3(side * (W / 2 - t / 2), y, L / 2 - t / 2), pinMaterial, chamfer: 0.0005)
            }
        }

        // 前板上的拉手凹槽与黄铜标签框。
        let pull = SCNBox(width: 0.058, height: 0.015, length: 0.002, chamferRadius: 0.0074)
        pull.materials = [material(color: SceneColor(white: 0.08, alpha: 1), roughness: 0.9)]
        let pullNode = SCNNode(geometry: pull)
        pullNode.simdPosition = SIMD3(0, H * 0.62, L / 2 + 0.0002)
        boxNode.addChildNode(pullNode)

        let brass = SCNMaterial()
        brass.lightingModel = .physicallyBased
        brass.diffuse.contents = SceneColor(red: 0.80, green: 0.64, blue: 0.36, alpha: 1)
        brass.metalness.contents = 1.0
        brass.roughness.contents = 0.32
        let frame = SCNBox(width: 0.05, height: 0.022, length: 0.0016, chamferRadius: 0.0015)
        frame.materials = [brass]
        let frameNode = SCNNode(geometry: frame)
        frameNode.simdPosition = SIMD3(0, H * 0.3, L / 2 + 0.0006)
        boxNode.addChildNode(frameNode)
        let label = SCNBox(width: 0.042, height: 0.015, length: 0.0012, chamferRadius: 0.0005)
        let labelMaterial = material(color: SceneColor(white: 1, alpha: 1), roughness: 0.8)
        labelMaterial.diffuse.contents = ProceduralTextures.label("A–Z", width: 192, height: 72, background: "#F3EBD8")
        label.materials = [labelMaterial, paperMaterial, paperMaterial, paperMaterial, paperMaterial, paperMaterial]
        let labelNode = SCNNode(geometry: label)
        labelNode.simdPosition = SIMD3(0, H * 0.3, L / 2 + 0.0012)
        boxNode.addChildNode(labelNode)
    }

    // MARK: - Cards

    private func cardSize(_ record: PhotoRecord) -> SIMD2<Float> {
        let aspect = Float(record.layout.aspect)
        var height: Float = 0.134
        var width = height * aspect
        if width > 0.15 {
            width = 0.15
            height = width / aspect
        }
        return SIMD2(width, height)
    }

    private func makeCard(for record: PhotoRecord) {
        let size = cardSize(record)
        let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(cardThickness), chamferRadius: 0.0003)
        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = SceneColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
        front.roughness.contents = 0.32
        front.metalness.contents = 0.0
        front.clearCoat.contents = 0.65
        front.clearCoatRoughness.contents = 0.12
        let swatch = FilmCatalog.stock(id: record.stockID).swatch.first.flatMap { RGB(hex: $0) } ?? RGB(0.8, 0.76, 0.68)
        let top = material(color: SceneColor(red: CGFloat(swatch.x), green: CGFloat(swatch.y), blue: CGFloat(swatch.z), alpha: 1), roughness: 0.7)
        box.materials = [front, paperMaterial, paperMaterial, paperMaterial, top, paperMaterial]

        let card = SCNNode(geometry: box)
        card.name = "card:\(record.id.uuidString)"
        card.castsShadow = true
        let holder = SCNNode()
        holder.name = card.name
        holder.addChildNode(card)
        world.addChildNode(holder)
        holders[record.id] = holder
        cards[record.id] = card
        fronts[record.id] = front
        if let image = model?.images[record.id] {
            front.diffuse.contents = image
            appliedImages.insert(record.id)
        }
    }

    private func removeCard(_ id: UUID) {
        holders[id]?.removeFromParentNode()
        holders[id] = nil
        cards[id] = nil
        fronts[id] = nil
        placements[id] = nil
        appliedImages.remove(id)
    }

    private func applyImages(_ images: [UUID: CGImage]) {
        for (id, image) in images where !appliedImages.contains(id) {
            guard let front = fronts[id] else { continue }
            front.diffuse.contents = image
            appliedImages.insert(id)
        }
    }

    // MARK: - Layout

    private func boxToWorld(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let c = cos(boxYaw)
        let s = sin(boxYaw)
        return boxCenter + SIMD3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)
    }

    private func drawerSpacing(count: Int) -> Float {
        min(0.0064, (boxLength - 0.06) / Float(max(count, 1)))
    }

    private func drawerPosition(slot: Int, count: Int, height: Float) -> SIMD3<Float> {
        let z = boxLength / 2 - 0.032 - Float(slot) * drawerSpacing(count: count)
        return boxToWorld(SIMD3(0, wall + height / 2 + 0.0015, z))
    }

    private func pilePose(index: Int, count: Int, record: PhotoRecord) -> (position: SIMD3<Float>, yaw: Float) {
        let fromTop = count - 1 - index
        let slot = PileLayout.slot(index: fromTop, seed: record.seed)
        let scale: Float = 0.00064
        let y = cardThickness / 2 + 0.0004 + Float(index) * (cardThickness + 0.0003)
        let offset = SIMD3<Float>(Float(slot.offset.width) * scale, y, Float(slot.offset.height) * scale)
        return (pileCenter + offset, Float(slot.rotation) * .pi / 180)
    }

    private func sync(records: [PhotoRecord], pulled: [UUID], animated: Bool) {
        let ids = Set(records.map(\.id))
        for id in Array(holders.keys) where !ids.contains(id) {
            removeCard(id)
        }
        var fresh = Set<UUID>()
        for record in records where holders[record.id] == nil {
            makeCard(for: record)
            fresh.insert(record.id)
        }
        let pulledSet = Set(pulled)
        let drawer = IndexLetter.group(records.filter { !pulledSet.contains($0.id) }).flatMap { $0.records }
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for (slot, record) in drawer.enumerated() {
            place(record, at: .drawer(slot), drawerCount: drawer.count, pileCount: pulled.count, animated: animated && !fresh.contains(record.id))
        }
        for (index, id) in pulled.enumerated() {
            guard let record = byID[id] else { continue }
            place(record, at: .pile(index), drawerCount: drawer.count, pileCount: pulled.count, animated: animated && !fresh.contains(id))
        }
        layoutDividers(drawer: drawer, animated: animated)

        if let model {
            for id in pulled {
                if let record = byID[id] { model.loadImage(for: record) }
            }
            for record in drawer.prefix(2) {
                model.loadImage(for: record)
            }
        }
    }

    private func place(_ record: PhotoRecord, at placement: Placement, drawerCount: Int, pileCount: Int, animated: Bool) {
        guard let holder = holders[record.id], let card = cards[record.id] else { return }
        let previous = placements[record.id]
        placements[record.id] = placement
        let size = cardSize(record)

        let target: SIMD3<Float>
        let yaw: Float
        let pitch: Float
        switch placement {
        case .drawer(let slot):
            target = drawerPosition(slot: slot, count: drawerCount, height: size.y)
            yaw = boxYaw
            pitch = lean
        case .pile(let index):
            let pose = pilePose(index: index, count: pileCount, record: record)
            target = pose.position
            yaw = pose.yaw
            pitch = -.pi / 2
        }

        guard animated, let previous else {
            holder.removeAllActions()
            card.removeAllActions()
            holder.simdPosition = target
            holder.simdEulerAngles = SIMD3(0, yaw, 0)
            card.simdEulerAngles = SIMD3(pitch, 0, 0)
            return
        }

        switch (previous, placement) {
        case (.drawer, .pile):
            animatePull(holder: holder, card: card, to: target, yaw: yaw)
        case (.pile, .drawer):
            animatePutBack(holder: holder, card: card, to: target, yaw: yaw)
        case (.pile, .pile):
            if previous != placement || simd_distance(holder.simdPosition, target) > 0.0005 {
                animateRestack(holder: holder, to: target, yaw: yaw)
            }
        case (.drawer, .drawer):
            if simd_distance(holder.simdPosition, target) > 0.0003 {
                let slide = SCNAction.move(to: SCNVector3(target), duration: 0.32)
                slide.timingMode = .easeInEaseOut
                holder.runAction(slide)
            }
        }
    }

    private func animatePull(holder: SCNNode, card: SCNNode, to target: SIMD3<Float>, yaw: Float) {
        holder.removeAllActions()
        card.removeAllActions()
        let start = holder.simdPosition
        let lift = SCNAction.move(to: SCNVector3(start + SIMD3(0, 0.12, 0)), duration: 0.24)
        lift.timingMode = .easeOut
        let over = SCNAction.move(to: SCNVector3(target + SIMD3(0, 0.06, 0)), duration: 0.44)
        over.timingMode = .easeInEaseOut
        let turn = SCNAction.rotateTo(x: 0, y: CGFloat(yaw), z: 0, duration: 0.44, usesShortestUnitArc: true)
        turn.timingMode = .easeInEaseOut
        let land = SCNAction.move(to: SCNVector3(target), duration: 0.18)
        land.timingMode = .easeIn
        holder.runAction(.sequence([lift, .group([over, turn]), land]))

        let flatten = SCNAction.rotateTo(x: CGFloat(-Float.pi / 2), y: 0, z: 0, duration: 0.46, usesShortestUnitArc: true)
        flatten.timingMode = .easeInEaseOut
        card.runAction(.sequence([.wait(duration: 0.2), flatten]))
    }

    private func animatePutBack(holder: SCNNode, card: SCNNode, to target: SIMD3<Float>, yaw: Float) {
        holder.removeAllActions()
        card.removeAllActions()
        let start = holder.simdPosition
        let up = SCNAction.move(to: SCNVector3(start + SIMD3(0, 0.05, 0)), duration: 0.16)
        up.timingMode = .easeOut
        let above = SCNAction.move(to: SCNVector3(target + SIMD3(0, 0.13, 0)), duration: 0.44)
        above.timingMode = .easeInEaseOut
        let turn = SCNAction.rotateTo(x: 0, y: CGFloat(yaw), z: 0, duration: 0.44, usesShortestUnitArc: true)
        let down = SCNAction.move(to: SCNVector3(target), duration: 0.26)
        down.timingMode = .easeOut
        holder.runAction(.sequence([up, .group([above, turn]), down]))

        let stand = SCNAction.rotateTo(x: CGFloat(lean), y: 0, z: 0, duration: 0.42, usesShortestUnitArc: true)
        stand.timingMode = .easeInEaseOut
        card.runAction(.sequence([.wait(duration: 0.1), stand]))
    }

    private func animateRestack(holder: SCNNode, to target: SIMD3<Float>, yaw: Float) {
        holder.removeAllActions()
        let start = holder.simdPosition
        let turn = SCNAction.rotateTo(x: 0, y: CGFloat(yaw), z: 0, duration: 0.3, usesShortestUnitArc: true)
        if target.y < start.y - 0.002 {
            // 从最上面换到下面：先滑出去，再从下面塞回来（像翻一叠照片）。
            let side = SIMD3<Float>(0.17, 0, 0.03)
            let out = SCNAction.move(to: SCNVector3(start + side + SIMD3(0, 0.02, 0)), duration: 0.24)
            out.timingMode = .easeOut
            let drop = SCNAction.move(to: SCNVector3(SIMD3(target.x + side.x, target.y, target.z + side.z)), duration: 0.12)
            let back = SCNAction.move(to: SCNVector3(target), duration: 0.3)
            back.timingMode = .easeInEaseOut
            holder.runAction(.sequence([out, drop, .group([back, turn])]))
        } else {
            let liftY = max(start.y, target.y) + 0.025
            let up = SCNAction.move(to: SCNVector3(SIMD3(start.x, liftY, start.z)), duration: 0.12)
            up.timingMode = .easeOut
            let across = SCNAction.move(to: SCNVector3(SIMD3(target.x, liftY, target.z)), duration: 0.26)
            across.timingMode = .easeInEaseOut
            let down = SCNAction.move(to: SCNVector3(target), duration: 0.12)
            down.timingMode = .easeIn
            holder.runAction(.sequence([up, .group([across, turn]), down]))
        }
    }

    // MARK: - Dividers

    private func layoutDividers(drawer: [PhotoRecord], animated: Bool) {
        var firstSlot: [String: Int] = [:]
        for (slot, record) in drawer.enumerated() where firstSlot[record.indexLetter] == nil {
            firstSlot[record.indexLetter] = slot
        }
        for (letter, node) in dividers where firstSlot[letter] == nil {
            node.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
            dividers[letter] = nil
        }
        let spacing = drawerSpacing(count: drawer.count)
        for (letter, slot) in firstSlot {
            let z = boxLength / 2 - 0.032 - Float(slot) * spacing + spacing * 0.5
            let position = boxToWorld(SIMD3(0, wall + dividerHeight / 2 + 0.0015, z))
            if let node = dividers[letter] {
                if animated {
                    let move = SCNAction.move(to: SCNVector3(position), duration: 0.32)
                    move.timingMode = .easeInEaseOut
                    node.runAction(move)
                } else {
                    node.simdPosition = position
                }
                node.simdEulerAngles = SIMD3(0, boxYaw, 0)
            } else {
                let node = makeDivider(letter: letter)
                node.simdPosition = position
                node.simdEulerAngles = SIMD3(0, boxYaw, 0)
                if animated {
                    node.opacity = 0
                    node.runAction(.fadeIn(duration: 0.25))
                }
                dividers[letter] = node
            }
        }
    }

    private func makeDivider(letter: String) -> SCNNode {
        let width = boxWidth - 2 * wall - 0.008
        let plate = SCNBox(width: CGFloat(width), height: CGFloat(dividerHeight), length: 0.0012, chamferRadius: 0.0004)
        plate.materials = [dividerMaterial]
        let holder = SCNNode()
        holder.name = "divider:\(letter)"
        let tilted = SCNNode(geometry: plate)
        tilted.name = holder.name
        tilted.simdEulerAngles = SIMD3(lean, 0, 0)
        holder.addChildNode(tilted)

        let tab = SCNBox(width: 0.03, height: 0.02, length: 0.0013, chamferRadius: 0.003)
        let face = material(color: SceneColor(white: 1, alpha: 1), roughness: 0.85)
        face.diffuse.contents = ProceduralTextures.label(letter)
        tab.materials = [face, dividerMaterial, face, dividerMaterial, dividerMaterial, dividerMaterial]
        let tabNode = SCNNode(geometry: tab)
        tabNode.name = holder.name
        let index = IndexLetter.all.firstIndex(of: letter) ?? 0
        let columns = 6
        let x = -width / 2 + 0.022 + Float(index % columns) * ((width - 0.044) / Float(columns - 1))
        tabNode.simdPosition = SIMD3(x, dividerHeight / 2 + 0.009, 0)
        tilted.addChildNode(tabNode)
        world.addChildNode(holder)
        return holder
    }
}

/// 接收手势的 Objective-C 目标（场景本身不继承 NSObject，避免 actor 隔离冲突）。
final class SceneGestureTarget: NSObject {
    var onHit: ((CGPoint, SCNView, Bool) -> Void)?

    #if canImport(UIKit)
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        onHit?(recognizer.location(in: view), view, false)
    }

    @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        onHit?(recognizer.location(in: view), view, true)
    }
    #elseif canImport(AppKit)
    @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        onHit?(recognizer.location(in: view), view, false)
    }

    @objc func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        onHit?(recognizer.location(in: view), view, true)
    }
    #endif
}
