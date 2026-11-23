import AppKit
import SceneKit
import simd
import SwiftUI

/// 大头贴机的 3D 布帘：两幅打褶的陶土橙丝绒帘、顶部帘头、黄铜帘杆和帘环。
///
/// 用 SceneKit 实时打光：褶皱的明暗来自真实法线，帘子落下时会轻轻摆动。
/// 背景透明，叠在取景框之上；中间留出取景框的位置。
@MainActor
final class CurtainScene {
    let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let root = SCNNode()
    private var panels: [SCNNode] = []
    private var height: Float = 0.982

    init() {
        scene.rootNode.addChildNode(root)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 0.01
        camera.zFar = 20
        cameraNode.camera = camera
        cameraNode.simdPosition = SIMD3(0, 0, 5)
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1150
        key.color = NSColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdEulerAngles = SIMD3(-0.45, -0.75, 0)
        scene.rootNode.addChildNode(keyNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 420
        rim.color = NSColor(red: 1.0, green: 0.72, blue: 0.55, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.simdEulerAngles = SIMD3(-0.2, 0.95, 0)
        scene.rootNode.addChildNode(rimNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 170
        ambient.color = NSColor(red: 1.0, green: 0.92, blue: 0.86, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    func makeView() -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.pointOfView = cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isPlaying = true
        return view
    }

    /// 按屏幕尺寸（点）搭布帘；`gap` 是中间留给取景框的宽度。
    func build(screen size: CGSize, gap: CGFloat) {
        root.childNodes.forEach { $0.removeFromParentNode() }
        panels.removeAll()
        let w = Float(size.width) / 1000
        let h = Float(size.height) / 1000
        height = h
        cameraNode.camera?.orthographicScale = Double(h / 2)

        let velvet = Self.velvetMaterial()
        let gapW = Float(gap) / 1000
        let panelW = max(0.12, (w - gapW) / 2 + 0.03)
        let pleats = max(6, Int(panelW / 0.055))

        for side: Float in [-1, 1] {
            let geometry = Self.pleatedPanel(width: panelW, height: h * 1.02, pleats: pleats, depth: 0.02)
            geometry.materials = [velvet]
            let node = SCNNode(geometry: geometry)
            // 以顶边为轴，方便摆动。
            node.pivot = SCNMatrix4MakeTranslation(0, CGFloat(h * 0.51), 0)
            node.simdPosition = SIMD3(side * (w / 2 - panelW / 2), h * 0.51 - h * 0.02, 0)
            root.addChildNode(node)
            panels.append(node)
        }

        // 帘头（短褶）+ 金色滚边。
        let valanceH = h * 0.1
        let valance = Self.pleatedPanel(width: w * 1.02, height: valanceH, pleats: max(10, Int(w / 0.028)), depth: 0.009)
        valance.materials = [velvet]
        let valanceNode = SCNNode(geometry: valance)
        valanceNode.simdPosition = SIMD3(0, h / 2 - valanceH / 2, 0.04)
        root.addChildNode(valanceNode)

        let gold = Self.brassMaterial()
        let trim = SCNBox(width: CGFloat(w * 1.02), height: CGFloat(h * 0.008), length: 0.012, chamferRadius: 0.002)
        trim.materials = [gold]
        let trimNode = SCNNode(geometry: trim)
        trimNode.simdPosition = SIMD3(0, h / 2 - valanceH, 0.05)
        root.addChildNode(trimNode)

        // 黄铜帘杆与帘环。
        let rod = SCNCylinder(radius: CGFloat(h * 0.0075), height: CGFloat(w * 1.04))
        rod.materials = [gold]
        let rodNode = SCNNode(geometry: rod)
        rodNode.simdEulerAngles = SIMD3(0, 0, .pi / 2)
        rodNode.simdPosition = SIMD3(0, h / 2 - h * 0.012, 0.075)
        root.addChildNode(rodNode)
        let ringCount = max(8, Int(w / 0.09))
        for i in 0..<ringCount {
            let ring = SCNTorus(ringRadius: CGFloat(h * 0.012), pipeRadius: CGFloat(h * 0.0022))
            ring.materials = [gold]
            let ringNode = SCNNode(geometry: ring)
            ringNode.simdEulerAngles = SIMD3(0, 0, .pi / 2)
            let x = -w / 2 + w * (Float(i) + 0.5) / Float(ringCount)
            ringNode.simdPosition = SIMD3(x, h / 2 - h * 0.012, 0.075)
            root.addChildNode(ringNode)
        }

        root.simdPosition = SIMD3(0, h * 1.05, 0)
    }

    /// 布帘从刘海落下来，落定后轻轻摆。
    func drop(duration: TimeInterval = 0.9) {
        root.removeAllActions()
        let fall = SCNAction.move(to: SCNVector3(0, -height * 0.012, 0), duration: duration * 0.78)
        fall.timingMode = .easeIn
        let settle = SCNAction.move(to: SCNVector3(0, 0, 0), duration: duration * 0.22)
        settle.timingMode = .easeOut
        root.runAction(.sequence([fall, settle]))
        for (index, panel) in panels.enumerated() {
            panel.removeAllActions()
            let sign: CGFloat = index == 0 ? 1 : -1
            let swingA = SCNAction.rotateBy(x: 0, y: 0, z: 0.012 * sign, duration: 0.5)
            swingA.timingMode = .easeInEaseOut
            let swingB = SCNAction.rotateBy(x: 0, y: 0, z: -0.02 * sign, duration: 0.8)
            swingB.timingMode = .easeInEaseOut
            let swingC = SCNAction.rotateBy(x: 0, y: 0, z: 0.008 * sign, duration: 0.7)
            swingC.timingMode = .easeInEaseOut
            let idleA = SCNAction.rotateBy(x: 0, y: 0, z: 0.003 * sign, duration: 2.2)
            idleA.timingMode = .easeInEaseOut
            let idleB = SCNAction.rotateBy(x: 0, y: 0, z: -0.003 * sign, duration: 2.2)
            idleB.timingMode = .easeInEaseOut
            panel.runAction(.sequence([.wait(duration: duration * 0.75), swingA, swingB, swingC, .repeatForever(.sequence([idleA, idleB]))]))
        }
    }

    /// 拉开帘子（升回刘海）。
    func raise(duration: TimeInterval = 0.8) {
        root.removeAllActions()
        let up = SCNAction.move(to: SCNVector3(0, height * 1.05, 0), duration: duration)
        up.timingMode = .easeIn
        root.runAction(up)
    }

    // MARK: - Geometry & materials

    /// 一幅打褶的布：正弦褶皱，越往下褶越深（布料自然垂坠）。
    static func pleatedPanel(width: Float, height: Float, pleats: Int, depth: Float, columns: Int = 180, rows: Int = 28) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []
        vertices.reserveCapacity((columns + 1) * (rows + 1))
        let k = Float(pleats) * 2 * .pi / width
        for r in 0...rows {
            let v = Float(r) / Float(rows)
            let y = height * (v - 0.5)
            let d = depth * (0.7 + 0.3 * (1 - v))
            for c in 0...columns {
                let u = Float(c) / Float(columns)
                let x = width * (u - 0.5)
                let z = sin(k * x) * d + sin(k * 0.5 * x + 1.3) * d * 0.28
                let dzdx = cos(k * x) * d * k + cos(k * 0.5 * x + 1.3) * d * 0.28 * k * 0.5
                let n = simd_normalize(SIMD3<Float>(-dzdx, 0, 1))
                vertices.append(SCNVector3(x, y, z))
                normals.append(SCNVector3(n))
                uvs.append(CGPoint(x: CGFloat(u * Float(pleats) * 0.5), y: CGFloat((1 - v) * height * 4)))
            }
        }
        let stride = UInt32(columns + 1)
        for r in 0..<rows {
            for c in 0..<columns {
                let i = UInt32(r) * stride + UInt32(c)
                let j = i + stride
                indices.append(contentsOf: [i, i + 1, j, i + 1, j + 1, j])
            }
        }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        return geometry
    }

    static func velvetMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.isDoubleSided = true
        if let texture = NSImage(named: "VelvetTexture") {
            m.diffuse.contents = texture
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
        } else {
            m.diffuse.contents = NSColor(red: 0.58, green: 0.22, blue: 0.14, alpha: 1)
        }
        m.roughness.contents = 0.86
        m.metalness.contents = 0.0
        return m
    }

    static func brassMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(red: 0.84, green: 0.66, blue: 0.36, alpha: 1)
        m.metalness.contents = 1.0
        m.roughness.contents = 0.3
        return m
    }
}

/// SwiftUI 里放 3D 布帘的透明视图。
struct CurtainSceneView: NSViewRepresentable {
    let curtain: CurtainScene

    func makeNSView(context: Context) -> SCNView {
        curtain.makeView()
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}
}
