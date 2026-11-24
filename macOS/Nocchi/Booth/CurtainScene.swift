import AppKit
import Metal
import NocchiKit
import SceneKit
import simd
import SwiftUI

/// 大头贴机的 3D 丝绒布帘：两幅从屏幕两边沿帘杆拉过来的丝绒帘，顶上一条扇形垂边的帘头
/// （金色绞绳 + 一排流苏），黄铜帘杆和帘环。
///
/// - **褶皱**：几组不同频率的波叠出不规则的布褶，顺着布往下轻轻斜走；帘环处是整齐的小褶，往下慢慢散开。
///   褶的深浅按「布就这么多」来算：收拢时褶又窄又深，拉开时又宽又浅。
/// - **丝绒**：正对着看的地方压得深、掠射角泛起暖色光泽（丝绒的边缘亮），褶谷里暗一些（顶点颜色里的环境遮蔽），
///   金属件反射一张程序化的暖色环境图。
/// - **动态**：帘杆按「先快后慢」的手势拉；布的下摆是两个阻尼振子（一个慢的整体摆、一个快的腰部），
///   所以下摆慢半拍、甩过头、来回摆几下再停；拉上之后布在 GPU 上轻轻「呼吸」。帘头先落下、弹一下，流苏跟着颤；
///   拉开时布收回两边，最后帘头升回去。
@MainActor
final class CurtainScene {
    let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let root = SCNNode()
    private let valanceRoot = SCNNode()
    private var panels: [CurtainPanel] = []
    private var fringeMaterial: SCNMaterial?
    private var height: Float = 0.982
    private var ticker: FrameTicker?
    private var clock: TimeInterval = 0

    /// 帘杆：0 = 收在两边（屏幕外），1 = 拉上（只留中间的取景框）。
    private var rod: Float = 0
    private var rodVelocity: Float = 0
    private var rodMove: Move?
    /// 帘头：落下 / 升起（时间都记在 `clock` 上）。
    private var valanceMove: ValanceMove = .rest

    private struct Move {
        let from: Float
        let to: Float
        let start: TimeInterval
        let duration: TimeInterval
    }

    private enum ValanceMove {
        case rest
        case dropping(start: TimeInterval)
        case lifting(start: TimeInterval)
    }

    private static let fallTime: Float = 0.34
    private static let liftTime: Float = 0.36

    init() {
        scene.rootNode.addChildNode(root)
        root.addChildNode(valanceRoot)
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = Self.environmentImage()
        scene.lightingEnvironment.intensity = 0.85

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 0.01
        camera.zFar = 20
        cameraNode.camera = camera
        cameraNode.simdPosition = SIMD3(0, 0, 5)
        scene.rootNode.addChildNode(cameraNode)

        // 全局统一：左上方的暖光。
        let key = SCNLight()
        key.type = .directional
        key.intensity = 980
        key.color = NSColor(red: 1.0, green: 0.9, blue: 0.79, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdEulerAngles = SIMD3(-0.5, -0.8, 0)
        scene.rootNode.addChildNode(keyNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 300
        rim.color = NSColor(red: 1.0, green: 0.7, blue: 0.55, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.simdEulerAngles = SIMD3(-0.15, 1.0, 0)
        scene.rootNode.addChildNode(rimNode)

        // 中间大头贴机的暖光，打在两幅帘子靠里的褶上。
        let booth = SCNLight()
        booth.type = .omni
        booth.intensity = 420
        booth.color = NSColor(red: 1.0, green: 0.78, blue: 0.52, alpha: 1)
        booth.attenuationStartDistance = 0.25
        booth.attenuationEndDistance = 1.2
        let boothNode = SCNNode()
        boothNode.light = booth
        boothNode.simdPosition = SIMD3(0, 0.08, 0.4)
        scene.rootNode.addChildNode(boothNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 60
        ambient.color = NSColor(red: 1.0, green: 0.9, blue: 0.84, alpha: 1)
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

    /// 按屏幕尺寸（点）搭布帘；`gap` 是中间留给取景框的宽度。搭好时帘子收在屏幕外、帘头在上面。
    func build(screen size: CGSize, gap: CGFloat) {
        ticker?.stop()
        ticker = nil
        rodMove = nil
        root.childNodes.filter { $0 !== valanceRoot }.forEach { $0.removeFromParentNode() }
        valanceRoot.childNodes.forEach { $0.removeFromParentNode() }
        panels.removeAll()

        let w = Float(size.width) / 1000
        let h = Float(size.height) / 1000
        height = h
        cameraNode.camera?.orthographicScale = Double(h / 2)

        let valanceH = h * 0.085
        let top = h / 2 - valanceH * 0.4
        let gapW = Float(gap) / 1000
        let gathered: Float = 0.05
        // 收起时整幅都在屏幕外；拉上时领头的边伸进取景框 40pt（被机身挡住）。
        let offscreen = gathered + 0.016
        let full = max(0.16, (w - gapW) / 2 + 0.04 + offscreen)
        let folds = max(7, Int((full / 0.052).rounded()))
        for (index, side) in [Float(1), Float(-1)].enumerated() {
            let panel = CurtainPanel(
                outerX: side > 0 ? -w / 2 - offscreen : w / 2 + offscreen,
                direction: side,
                fullWidth: full,
                gatheredWidth: gathered,
                height: h * 1.04,
                topY: top,
                folds: folds,
                seed: UInt64(index * 7919 + 17),
                material: Self.velvetMaterial(breathingTop: top, height: h)
            )
            root.addChildNode(panel.node)
            panels.append(panel)
        }
        rod = 0
        rodVelocity = 0
        panels.forEach { $0.reset(to: 0) }

        // 帘头：一段段扇形垂下的短褶丝绒 + 沿着垂边的金色绞绳 + 一排流苏。
        let span = w * 1.04
        let swags = max(4, Int((w / 0.26).rounded()))
        let hem = Hemline(width: span, swags: swags, dip: h * 0.013)
        let valance = SCNNode(geometry: Self.valance(
            width: span, height: valanceH, hem: hem, folds: max(16, Int(w / 0.021)), depth: 0.008,
            material: Self.velvetMaterial(breathingTop: nil, height: h)
        ))
        valance.simdPosition = SIMD3(0, h / 2 - valanceH / 2, 0.05)
        valanceRoot.addChildNode(valance)

        let gold = Self.brassMaterial()
        let cordRadius = h * 0.0052
        let cord = SCNNode(geometry: Self.cord(hem: hem, radius: cordRadius, material: gold))
        cord.simdPosition = SIMD3(0, h / 2 - valanceH, 0.062)
        valanceRoot.addChildNode(cord)

        let fringeGold = Self.makeFringeMaterial()
        fringeMaterial = fringeGold
        let fringe = SCNNode(geometry: Self.fringe(hem: hem, length: h * 0.022, count: max(140, Int(span / 0.0055)), material: fringeGold))
        fringe.simdPosition = SIMD3(0, h / 2 - valanceH - cordRadius * 0.6, 0.058)
        valanceRoot.addChildNode(fringe)

        // 黄铜帘杆与帘环（大多藏在菜单栏后面，帘头落下时能看到一闪）：帘环在每段垂边的两头和中间。
        let rodGeometry = SCNCylinder(radius: CGFloat(h * 0.0075), height: CGFloat(span))
        rodGeometry.materials = [gold]
        let rodNode = SCNNode(geometry: rodGeometry)
        rodNode.simdEulerAngles = SIMD3(0, 0, .pi / 2)
        rodNode.simdPosition = SIMD3(0, h / 2 - h * 0.012, 0.08)
        valanceRoot.addChildNode(rodNode)
        for i in 0...(swags * 2) {
            let ring = SCNTorus(ringRadius: CGFloat(h * 0.012), pipeRadius: CGFloat(h * 0.0022))
            ring.materials = [gold]
            let ringNode = SCNNode(geometry: ring)
            ringNode.simdEulerAngles = SIMD3(0, 0, .pi / 2)
            let x = -span / 2 + span * Float(i) / Float(swags * 2)
            ringNode.simdPosition = SIMD3(x, h / 2 - h * 0.012, 0.08)
            valanceRoot.addChildNode(ringNode)
        }
        valanceMove = .rest
        valanceRoot.simdPosition = SIMD3(0, valanceLift, 0)
        fringeGold.setValue(NSNumber(value: Float(0)), forKey: "bounce")
    }

    /// 拉上帘子：帘头先落下、弹一下，两幅帘子从两边沿帘杆拉过来，下摆慢半拍、甩一甩再停住。
    func drop(duration: TimeInterval = 0.9) {
        valanceMove = .dropping(start: clock)
        moveRod(to: 1, duration: duration, delay: 0.1)
    }

    /// 拉开帘子：两幅帘子收回屏幕外（稍微多拉一点，让落后的下摆也赶得上），最后帘头升回去。
    func raise(duration: TimeInterval = 0.8) {
        valanceMove = .lifting(start: clock + duration * 0.5)
        moveRod(to: -0.06, duration: duration * 0.85, delay: 0)
    }

    /// 截图工作室用：不开窗口，把拉上、停稳的布帘渲染成一张透明背景的图（没有 Metal 时返回 nil）。
    func renderClosed(size: CGSize, gap: CGFloat, scale: CGFloat = 2) -> NSImage? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        build(screen: size, gap: gap)
        rod = 1
        panels.forEach { $0.reset(to: 1) }
        valanceRoot.simdPosition = .zero
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        return renderer.snapshot(atTime: 1, with: CGSize(width: size.width * scale, height: size.height * scale), antialiasingMode: .multisampling4X)
    }

    // MARK: - 动态

    private var valanceLift: Float { height * 0.3 }

    private func moveRod(to target: Float, duration: TimeInterval, delay: TimeInterval) {
        rodMove = Move(from: rod, to: target, start: clock + delay, duration: max(0.2, duration))
        guard ticker == nil else { return }
        let ticker = FrameTicker { [weak self] dt in
            guard let self else { return false }
            return self.step(dt)
        }
        self.ticker = ticker
        ticker.start()
    }

    /// 一帧：帘杆按手势曲线走，布的下摆用阻尼振子跟上，帘头和流苏按时间轴动；全都停稳就停掉计时器
    /// （之后布的呼吸在 GPU 上，不占 CPU）。
    private func step(_ dt: TimeInterval) -> Bool {
        clock += dt
        var busy = false

        let previous = rod
        if let move = rodMove {
            let t = min(max((clock - move.start) / move.duration, 0), 1)
            rod = move.from + (move.to - move.from) * Self.pull(Float(t))
            if t >= 1 {
                rodMove = nil
            } else {
                busy = true
            }
        }
        rodVelocity = dt > 0 ? (rod - previous) / Float(dt) : 0
        for panel in panels {
            if panel.update(rod: rod, rodVelocity: rodVelocity, dt: Float(dt)) {
                busy = true
            }
        }
        if stepValance() {
            busy = true
        }
        if !busy {
            ticker = nil
            return false
        }
        return true
    }

    /// 帘头：加速落下 → 落到位弹两下（流苏被拽长再缩回）；升起时先慢后快。返回还在不在动。
    private func stepValance() -> Bool {
        switch valanceMove {
        case .rest:
            return false
        case let .dropping(start):
            let tau = Float(clock - start)
            if tau < 0 { return true }
            if tau < Self.fallTime {
                let p = tau / Self.fallTime
                let y: Float = valanceLift * (1 - p * p)
                valanceRoot.simdPosition = SIMD3<Float>(0, y, 0)
                return true
            }
            let settle = tau - Self.fallTime
            if settle > 1.4 {
                valanceRoot.simdPosition = .zero
                fringeMaterial?.setValue(NSNumber(value: Float(0)), forKey: "bounce")
                valanceMove = .rest
                return false
            }
            let bounce: Float = exp(-7 * settle) * sin(19 * settle)
            valanceRoot.simdPosition = SIMD3<Float>(0, -height * 0.006 * bounce, 0)
            let recoil: Float = exp(-4.5 * settle) * cos(17 * settle)
            let stretch: Float = -height * 0.004 * recoil
            fringeMaterial?.setValue(NSNumber(value: stretch), forKey: "bounce")
            return true
        case let .lifting(start):
            let tau = Float(clock - start)
            if tau < 0 { return true }
            let p = min(tau / Self.liftTime, 1)
            let y: Float = valanceLift * p * p
            valanceRoot.simdPosition = SIMD3<Float>(0, y, 0)
            if p >= 1 {
                valanceMove = .rest
                return false
            }
            return true
        }
    }

    /// 手拉帘子的速度曲线：起步柔和、很快到最快，然后长长地慢下来停住（首尾速度都是 0）。
    nonisolated static func pull(_ t: Float) -> Float {
        let p = pow(min(max(t, 0), 1), 0.82)
        return (1 - cos(.pi * p)) / 2
    }

    // MARK: - Materials

    /// 丝绒：正对着看压得深、掠射角泛起顺着主光的暖色光泽。`breathingTop` 不为 nil 时，布在 GPU 上轻轻呼吸
    /// （越往下摆得越多，法线也跟着轻轻起伏，褶上的光会慢慢流动）。
    static func velvetMaterial(breathingTop: Float?, height: Float) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.isDoubleSided = true
        if let texture = NSImage(named: "VelvetTexture") {
            m.diffuse.contents = texture
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.mipFilter = .linear
        } else {
            m.diffuse.contents = NSColor(red: 0.5, green: 0.16, blue: 0.11, alpha: 1)
        }
        // 比纹理再深一点的陶土红：丝绒的绒毛把光吃进去。
        m.multiply.contents = NSColor(red: 0.84, green: 0.64, blue: 0.6, alpha: 1)
        m.roughness.contents = 0.92
        m.metalness.contents = 0.0
        var modifiers: [SCNShaderModifierEntryPoint: String] = [
            .surface: """
            float3 n = normalize(_surface.normal);
            float3 toEye = normalize(_surface.view);
            float facing = clamp(dot(n, toEye), 0.0, 1.0);
            float rim = pow(1.0 - facing, 2.4);
            float3 toKey = normalize(float3(-0.62, 0.42, 0.66));
            float lit = clamp(dot(n, toKey) * 0.5 + 0.5, 0.0, 1.0);
            _surface.diffuse.rgb *= mix(0.8, 1.06, rim);
            _surface.emission.rgb += float3(0.95, 0.52, 0.38) * rim * lit * 0.38;
            """
        ]
        if let top = breathingTop {
            modifiers[.geometry] = """
            float hang = clamp((\(top) - _geometry.position.y) / \(height), 0.0, 1.0);
            float k = hang * hang;
            float t = scn_frame.time;
            float sway = sin(t * 0.85 + _geometry.position.y * 1.7) * 0.65 + sin(t * 0.47 + 2.1) * 0.35;
            _geometry.position.x += sway * 0.0034 * k;
            float ripple = sin(t * 0.7 + _geometry.position.x * 9.0 - _geometry.position.y * 2.0);
            _geometry.normal = normalize(_geometry.normal + float3(ripple * 0.06 * k, 0.0, 0.0));
            """
        }
        m.shaderModifiers = modifiers
        return m
    }

    static func brassMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(red: 0.86, green: 0.68, blue: 0.38, alpha: 1)
        m.metalness.contents = 1.0
        m.roughness.contents = 0.32
        return m
    }

    /// 流苏：黄铜色细线。尖端（顶点的 z > 0）随帘头落地被拽长再缩回（`bounce`，CPU 每帧给），平时左右轻轻晃。
    static func makeFringeMaterial() -> SCNMaterial {
        let m = brassMaterial()
        m.isDoubleSided = true
        m.roughness.contents = 0.42
        m.shaderModifiers = [
            .geometry: """
            #pragma arguments
            float bounce;
            #pragma body
            float tip = clamp(_geometry.position.z / 0.0015, 0.0, 1.0);
            float t = scn_frame.time;
            _geometry.position.x += sin(t * 1.3 + _geometry.position.x * 23.0) * 0.0006 * tip;
            _geometry.position.y += bounce * tip * (1.0 + 0.3 * sin(_geometry.position.x * 61.0));
            """
        ]
        return m
    }

    /// 金属件反射的环境：上亮下暗的暖色渐变，左上方一团柔和的高光（程序化，不打包贴图）。
    static func environmentImage() -> CGImage? {
        let width = 256
        let height = 128
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // CGContext 的 y 轴朝上：y = 0 是「地面」（暗），y = height 是「天花板」（亮）。
        let colors = [
            CGColor(srgbRed: 0.05, green: 0.035, blue: 0.03, alpha: 1),
            CGColor(srgbRed: 0.32, green: 0.2, blue: 0.13, alpha: 1),
            CGColor(srgbRed: 0.78, green: 0.62, blue: 0.46, alpha: 1),
            CGColor(srgbRed: 1.0, green: 0.93, blue: 0.82, alpha: 1)
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.42, 0.62, 1]) {
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        }
        let glow = [
            CGColor(srgbRed: 1, green: 0.96, blue: 0.88, alpha: 1),
            CGColor(srgbRed: 1, green: 0.9, blue: 0.75, alpha: 0)
        ] as CFArray
        if let spot = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
            let center = CGPoint(x: Double(width) * 0.38, y: Double(height) * 0.74)
            ctx.drawRadialGradient(spot, startCenter: center, startRadius: 0, endCenter: center, endRadius: 30, options: [])
        }
        return ctx.makeImage()
    }

    // MARK: - 帘头的几何

    /// 帘头的扇形垂边：每一段在中间垂下 `dip`，两头挂在帘环上。
    struct Hemline {
        let width: Float
        let swags: Int
        let dip: Float

        /// x 处垂边比直线低多少（≥ 0）。
        func drop(at x: Float) -> Float {
            let s = sin(.pi * (x / width + 0.5) * Float(swags))
            return dip * s * s
        }

        func slope(at x: Float) -> Float {
            let k = .pi * Float(swags) / width
            return dip * sin(2 * k * (x + width / 2)) * k
        }
    }

    /// 帘头：短而密的褶，下沿按 `hem` 垂成一段段扇形；褶谷里暗一些。
    static func valance(width: Float, height: Float, hem: Hemline, folds: Int, depth: Float, material: SCNMaterial) -> SCNGeometry {
        let columns = 360
        let rows = 12
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var shade: [SIMD4<Float>] = []
        var uvs: [CGPoint] = []
        let k = Float(folds) * 2 * .pi / width
        for r in 0...rows {
            let v = Float(r) / Float(rows)
            for c in 0...columns {
                let u = Float(c) / Float(columns)
                let x = width * (u - 0.5)
                // 越往下褶越深（下沿被垂边拉开）。
                let d = depth * (0.7 + 0.45 * v)
                let wave = sin(k * x) + 0.3 * sin(k * 0.47 * x + 1.3)
                let slopeMain: Float = cos(k * x) * k
                let slopeSlow: Float = 0.141 * k * cos(k * 0.47 * x + 1.3)
                let dzdx: Float = (slopeMain + slopeSlow) * d
                let y = height * (0.5 - v) - v * v * hem.drop(at: x)
                positions.append(SIMD3<Float>(x, y, wave * d))
                normals.append(simd_normalize(SIMD3<Float>(-dzdx, 0.25 * v * hem.slope(at: x), 1)))
                let ao = (0.66 + 0.34 * smooth(-1.1, 0.7, wave)) * (0.78 + 0.22 * v)
                shade.append(SIMD4<Float>(ao, ao, ao, 1))
                uvs.append(CGPoint(x: CGFloat(u * width / 0.32), y: CGFloat(v * height / 0.32)))
            }
        }
        let geometry = SCNGeometry(
            sources: [
                floatSource(positions, semantic: .vertex),
                floatSource(normals, semantic: .normal),
                SCNGeometrySource(textureCoordinates: uvs),
                colorSource(shade)
            ],
            elements: [grid(columns: columns, rows: rows, facingForward: true)]
        )
        geometry.materials = [material]
        return geometry
    }

    /// 沿着垂边的金色绞绳：三股螺旋（截面半径随角度和位置起伏），法线按曲面算。
    static func cord(hem: Hemline, radius: Float, material: SCNMaterial) -> SCNGeometry {
        let segments = max(200, Int(hem.width / 0.0025))
        let around = 12
        let twist: Float = 2 * .pi / (radius * 7)
        func point(_ x: Float, _ theta: Float) -> SIMD3<Float> {
            let r = radius * (1 + 0.2 * cos(3 * theta - twist * x))
            return SIMD3<Float>(x, -hem.drop(at: x) + r * cos(theta), r * sin(theta))
        }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        positions.reserveCapacity((segments + 1) * (around + 1))
        normals.reserveCapacity((segments + 1) * (around + 1))
        for i in 0...segments {
            let x = hem.width * (Float(i) / Float(segments) - 0.5)
            for j in 0...around {
                let theta = 2 * .pi * Float(j) / Float(around)
                positions.append(point(x, theta))
                // 外法线 = ∂P/∂θ × ∂P/∂x。
                let n = simd_cross(point(x, theta + 0.01) - point(x, theta - 0.01), point(x + 0.0005, theta) - point(x - 0.0005, theta))
                normals.append(simd_length(n) > 1e-12 ? simd_normalize(n) : SIMD3<Float>(0, 0, 1))
            }
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(segments * around * 6)
        let ring = UInt32(around + 1)
        for i in 0..<UInt32(segments) {
            for j in 0..<UInt32(around) {
                let a = i * ring + j
                let b = a + 1
                let c = a + ring
                let d = c + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        let geometry = SCNGeometry(
            sources: [floatSource(positions, semantic: .vertex), floatSource(normals, semantic: .normal)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return geometry
    }

    /// 一排流苏：顺着垂边挂下来的细线，长短、粗细、歪的方向各有一点不同（一个几何体）。
    /// 尖端的顶点 z 稍微往前一点（0.0015），着色器用它认出尖端。
    static func fringe(hem: Hemline, length: Float, count: Int, material: SCNMaterial) -> SCNGeometry {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var rng = SeededRandom(seed: 0xF21A6E)
        let spacing = hem.width / Float(count)
        // 细线是圆的：左右两边的法线往外偏，金色上才有一条亮线。
        let leftTop = simd_normalize(SIMD3<Float>(-0.55, 0.1, 1))
        let rightTop = simd_normalize(SIMD3<Float>(0.55, 0.1, 1))
        let rightTip = simd_normalize(SIMD3<Float>(0.55, -0.1, 1))
        let leftTip = simd_normalize(SIMD3<Float>(-0.55, -0.1, 1))
        for i in 0..<count {
            let x = -hem.width / 2 + spacing * (Float(i) + 0.5)
            let y0 = -hem.drop(at: x)
            let l = length * Float(rng.range(0.8, 1.0))
            let thread = spacing * Float(rng.range(0.34, 0.46))
            let lean = Float(rng.range(-0.0016, 0.0016))
            let base = UInt32(positions.count)
            positions.append(SIMD3<Float>(x - thread, y0, 0))
            positions.append(SIMD3<Float>(x + thread, y0, 0))
            positions.append(SIMD3<Float>(x + thread * 0.7 + lean, y0 - l, 0.0015))
            positions.append(SIMD3<Float>(x - thread * 0.7 + lean, y0 - l, 0.0015))
            normals.append(leftTop)
            normals.append(rightTop)
            normals.append(rightTip)
            normals.append(leftTip)
            // 正面朝镜头（逆时针）。
            indices.append(contentsOf: [base, base + 3, base + 1, base + 1, base + 3, base + 2])
        }
        let geometry = SCNGeometry(
            sources: [floatSource(positions, semantic: .vertex), floatSource(normals, semantic: .normal)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return geometry
    }

    // MARK: - 几何小工具

    nonisolated static func floatSource(_ values: [SIMD3<Float>], semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(
            data: data,
            semantic: semantic,
            vectorCount: values.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )
    }

    nonisolated static func colorSource(_ values: [SIMD4<Float>]) -> SCNGeometrySource {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(
            data: data,
            semantic: .color,
            vectorCount: values.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
    }

    /// 网格的三角形：行往下走（y 变小）。列往 +x 走时传 `facingForward: true`，往 −x 走时传 false，
    /// 这样正面（逆时针）都朝镜头。
    nonisolated static func grid(columns: Int, rows: Int, facingForward: Bool) -> SCNGeometryElement {
        var indices: [UInt32] = []
        indices.reserveCapacity(rows * columns * 6)
        let stride = UInt32(columns + 1)
        for r in 0..<UInt32(rows) {
            for c in 0..<UInt32(columns) {
                let i = r * stride + c
                let j = i + stride
                if facingForward {
                    indices.append(contentsOf: [i, j, i + 1, i + 1, j, j + 1])
                } else {
                    indices.append(contentsOf: [i, i + 1, j, i + 1, j + 1, j])
                }
            }
        }
        return SCNGeometryElement(indices: indices, primitiveType: .triangles)
    }

    nonisolated static func smooth(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - 一幅帘子

/// 一幅可以沿帘杆拉开 / 收拢的丝绒帘。
///
/// 每一行布的「展开量」= 帘杆 + 两个阻尼振子相对帘杆的偏差 × 各自的形状
/// （慢的整体摆 ∝ v^1.5，越往下越大；快的腰部 ∝ sin πv）。振子各自独立、线性、有阻尼，所以怎么拉都稳定。
/// 褶型（每个顶点 −1…1）在初始化时算好，每帧只按展开量算宽度和褶深，重算顶点与法线。
@MainActor
final class CurtainPanel {
    let node = SCNNode()
    private let outerX: Float
    private let direction: Float
    private let fullWidth: Float
    private let gatheredWidth: Float
    private let height: Float
    private let topY: Float
    private let folds: Int
    private static let columns = 220
    private static let rows = 48
    /// 一个褶用掉的布宽：布比拉满时的宽度多 35%，拉满也还有褶。
    private let fabricPerFold: Float
    private let profile: [Float]
    private let element: SCNGeometryElement
    private let texcoords: SCNGeometrySource
    private let shade: SCNGeometrySource
    private let material: SCNMaterial
    private var hem = Sway(omega: 10.5, zeta: 0.17)
    private var belly = Sway(omega: 24, zeta: 0.3)
    private var rod: Float = 0

    init(outerX: Float, direction: Float, fullWidth: Float, gatheredWidth: Float, height: Float, topY: Float, folds: Int, seed: UInt64, material: SCNMaterial) {
        self.outerX = outerX
        self.direction = direction
        self.fullWidth = fullWidth
        self.gatheredWidth = gatheredWidth
        self.height = height
        self.topY = topY
        self.folds = folds
        self.material = material
        fabricPerFold = fullWidth * 1.35 / Float(folds)

        var rng = SeededRandom(seed: seed)
        let waves: [(freq: Float, amp: Float, phase: Float, drift: Float)] = [
            (1.0, 1.0, Float(rng.range(0, 6.283)), Float(rng.range(-0.9, 0.9))),
            (0.55, 0.45, Float(rng.range(0, 6.283)), Float(rng.range(-1.6, 1.6))),
            (1.62, 0.24, Float(rng.range(0, 6.283)), Float(rng.range(-2.2, 2.2))),
            (2.35, 0.1, Float(rng.range(0, 6.283)), Float(rng.range(-2.8, 2.8)))
        ]
        let columns = Self.columns
        let rows = Self.rows
        let base = Float(folds) * 2 * .pi
        var profile: [Float] = []
        var shades: [SIMD4<Float>] = []
        var coords: [CGPoint] = []
        profile.reserveCapacity((rows + 1) * (columns + 1))
        shades.reserveCapacity((rows + 1) * (columns + 1))
        coords.reserveCapacity((rows + 1) * (columns + 1))
        for r in 0...rows {
            let v = Float(r) / Float(rows)
            // 帘环处是整齐的小褶，往下 18% 的高度里慢慢变成不规则的布褶。
            let regular = CurtainScene.smooth(0.18, 0, v)
            // 帘头下面那一截在阴影里。
            let underValance: Float = 0.72 + 0.28 * CurtainScene.smooth(0, 0.1, v)
            for c in 0...columns {
                let u = Float(c) / Float(columns)
                var fold: Float = 0
                for wave in waves {
                    fold += wave.amp * sin(base * wave.freq * u + wave.phase + wave.drift * v)
                }
                fold /= 1.25
                let p = regular * sin(base * u) + (1 - regular) * fold
                profile.append(p)
                let ao = (0.6 + 0.4 * CurtainScene.smooth(-1.0, 0.6, p)) * underValance
                shades.append(SIMD4<Float>(ao, ao, ao, 1))
                coords.append(CGPoint(x: CGFloat(u * fullWidth / 0.32), y: CGFloat(v * height / 0.32)))
            }
        }
        self.profile = profile
        shade = CurtainScene.colorSource(shades)
        texcoords = SCNGeometrySource(textureCoordinates: coords)
        // 左边那幅列往 +x 走，右边那幅往 −x 走：三角形的绕向跟着换，正面都朝镜头。
        element = CurtainScene.grid(columns: columns, rows: rows, facingForward: direction > 0)
    }

    func reset(to value: Float) {
        rod = value
        hem.reset(value)
        belly.reset(value)
        rebuild()
    }

    /// 一帧（4 个子步）：返回布还在不在动。
    func update(rod: Float, rodVelocity: Float, dt: Float) -> Bool {
        let steps = 4
        let h = min(dt, 1 / 30) / Float(steps)
        for _ in 0..<steps {
            hem.step(target: rod, targetVelocity: rodVelocity, dt: h)
            belly.step(target: rod, targetVelocity: rodVelocity, dt: h)
        }
        self.rod = rod
        rebuild()
        return hem.isMoving(around: rod) || belly.isMoving(around: rod)
    }

    private func rebuild() {
        let columns = Self.columns
        let rows = Self.rows
        let stride = columns + 1
        var positions = [SIMD3<Float>](repeating: .zero, count: (rows + 1) * stride)
        for r in 0...rows {
            let v = Float(r) / Float(rows)
            let swing: Float = (hem.position - rod) * pow(v, 1.5)
            let waist: Float = (belly.position - rod) * sin(Float.pi * v) * 0.8
            let e: Float = rod + swing + waist
            let open = min(max(e, 0), 1)
            // 收拢时下摆像钟一样稍微散开。
            let flare = 1 + 0.1 * v * v * (1 - open)
            let width = max(gatheredWidth * 0.5, gatheredWidth + (fullWidth - gatheredWidth) * e) * flare
            // 布就这么多：一个褶的宽度越窄，褶就越深（锯齿近似，再按正弦收一点）。
            let foldWidth = width / Float(folds)
            let slack = max(0, fabricPerFold * fabricPerFold - foldWidth * foldWidth)
            let sag: Float = 0.88 + 0.24 * v
            let depth: Float = min(0.032, 0.275 * sqrt(slack)) * sag
            let y = topY - v * height
            let row = r * stride
            for c in 0...columns {
                let u = Float(c) / Float(columns)
                positions[row + c] = SIMD3<Float>(outerX + direction * u * width, y, depth * profile[row + c])
            }
        }
        // 法线：相邻顶点差的叉积（右幅的列方向反过来，叉积也要翻过来）。
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 1), count: positions.count)
        for r in 0...rows {
            for c in 0...columns {
                let left = positions[r * stride + max(c - 1, 0)]
                let right = positions[r * stride + min(c + 1, columns)]
                let up = positions[max(r - 1, 0) * stride + c]
                let down = positions[min(r + 1, rows) * stride + c]
                var n = simd_cross(right - left, up - down)
                if direction < 0 { n = -n }
                let length = simd_length(n)
                if length > 1e-12 {
                    normals[r * stride + c] = n / length
                }
            }
        }
        let geometry = SCNGeometry(
            sources: [
                CurtainScene.floatSource(positions, semantic: .vertex),
                CurtainScene.floatSource(normals, semantic: .normal),
                texcoords,
                shade
            ],
            elements: [element]
        )
        geometry.materials = [material]
        node.geometry = geometry
    }
}

/// 一个跟着帘杆走的阻尼振子（布的一个摆动模态）。一半阻尼来自静止的空气、一半跟着帘杆走：
/// 匀速拉的时候下摆也落后一点，停下来就甩过头再回来。
private struct Sway {
    let omega: Float
    let zeta: Float
    var position: Float = 0
    var velocity: Float = 0

    init(omega: Float, zeta: Float) {
        self.omega = omega
        self.zeta = zeta
    }

    mutating func step(target: Float, targetVelocity: Float, dt: Float) {
        let relative = velocity - 0.5 * targetVelocity
        let accel = omega * omega * (target - position) - 2 * zeta * omega * relative
        velocity += accel * dt
        position += velocity * dt
    }

    func isMoving(around target: Float) -> Bool {
        abs(velocity) > 0.003 || abs(position - target) > 0.0015
    }

    mutating func reset(_ value: Float) {
        position = value
        velocity = 0
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
