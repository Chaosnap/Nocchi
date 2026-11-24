import AppKit
import NocchiKit
import SwiftUI

/// 软木板的灯光与显示设置：板子左下角钉着的「灯光」铜牌打开调节卡片，设置会记住。
///
/// 灯光引擎移植自所有者的 Typewriter Nocturne（MIT 许可）：白天太阳从窗户斜照进来，在板子上投出带窗格的光斑；
/// 夜里一盏台灯照出一团暖光，或者月光透过窗格；光里飘着灰尘。灯的位置、范围、亮度、色温、灰尘多少都能调，
/// 照片和图钉的影子跟着灯走。光照的计算在 `NocchiKit/Lighting/LightModel`，画法见 `CorkLightOverlay`。
struct CorkLighting: Codable, Hashable {
    enum Fastener: String, Codable, CaseIterable, Identifiable {
        case mixed
        case brass
        case mapPin
        case tape
        case clip

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mixed: String(localized: "混搭")
            case .brass: String(localized: "黄铜钉")
            case .mapPin: String(localized: "地图针")
            case .tape: String(localized: "胶带")
            case .clip: String(localized: "木夹")
            }
        }
    }

    /// 白天还是黑夜。
    enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
        case day
        case night

        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: String(localized: "白天")
            case .night: String(localized: "黑夜")
            }
        }

        var symbol: String {
            switch self {
            case .day: "sun.max.fill"
            case .night: "moon.stars.fill"
            }
        }
    }

    var time: TimeOfDay = .day
    /// 白天是窗户里的太阳光；夜里是台灯或月光。
    var source: LightSource = .sunlight
    /// 灯（或窗户）在板子的哪个位置（归一化，原点左上）。
    var lightX: Double = 0.16
    var lightY: Double = 0.12
    /// 范围：台灯挂多高（光斑多大）、窗户多大。
    var reach: Double = 0.55
    /// 光里飘的灰尘（0…1）。
    var particles: Double = 0.35
    /// 色温：0 = 暖（钨丝台灯），0.5 = 中性，1 = 冷（月光）。
    var temperature: Double = 0.42
    /// 亮度（0…1）。
    var intensity: Double = 0.55
    /// 暗角（0…1）。
    var vignette: Double = 0.4
    /// 阴影深浅（0…1）。
    var shadow: Double = 0.55
    /// 纸张卷曲（0…1）：照片上顺着光的明暗。
    var curl: Double = 0.45
    /// 照片的固定方式。
    var fastener: Fastener = .mixed

    static let standard = CorkLighting()

    /// 夜里的样子：一盏钨丝台灯挂在左上方。
    static let night: CorkLighting = {
        var lighting = CorkLighting()
        lighting.setTime(.night)
        lighting.lightX = 0.24
        lighting.lightY = 0.08
        lighting.particles = 0.55
        return lighting
    }()

    init() {}

    // MARK: 存取（2.x 存的是 `angle`：光从哪个方向来，度）

    private enum CodingKeys: String, CodingKey {
        case time, source, lightX, lightY, reach, particles, temperature, intensity, vignette, shadow, curl, fastener, angle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CorkLighting()
        time = (try? c.decodeIfPresent(TimeOfDay.self, forKey: .time)) ?? d.time
        source = (try? c.decodeIfPresent(LightSource.self, forKey: .source)) ?? d.source
        reach = (try? c.decodeIfPresent(Double.self, forKey: .reach)) ?? d.reach
        particles = (try? c.decodeIfPresent(Double.self, forKey: .particles)) ?? d.particles
        temperature = (try? c.decodeIfPresent(Double.self, forKey: .temperature)) ?? d.temperature
        intensity = (try? c.decodeIfPresent(Double.self, forKey: .intensity)) ?? d.intensity
        vignette = (try? c.decodeIfPresent(Double.self, forKey: .vignette)) ?? d.vignette
        shadow = (try? c.decodeIfPresent(Double.self, forKey: .shadow)) ?? d.shadow
        curl = (try? c.decodeIfPresent(Double.self, forKey: .curl)) ?? d.curl
        fastener = (try? c.decodeIfPresent(Fastener.self, forKey: .fastener)) ?? d.fastener
        if let x = try? c.decodeIfPresent(Double.self, forKey: .lightX), let y = try? c.decodeIfPresent(Double.self, forKey: .lightY) {
            lightX = x
            lightY = y
        } else if let angle = try? c.decodeIfPresent(Double.self, forKey: .angle) {
            // 旧的「光从哪个方向来」→ 灯在那一边。
            let radians = angle * .pi / 180
            lightX = min(1, max(0, 0.5 + cos(radians) * 0.36))
            lightY = min(1, max(0, 0.5 - sin(radians) * 0.42))
        } else {
            lightX = d.lightX
            lightY = d.lightY
        }
        // 白天只有太阳光；夜里只有台灯和月光。
        if time == .day, source != .sunlight { source = .sunlight }
        if time == .night, source == .sunlight { source = .deskLamp }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(time, forKey: .time)
        try c.encode(source, forKey: .source)
        try c.encode(lightX, forKey: .lightX)
        try c.encode(lightY, forKey: .lightY)
        try c.encode(reach, forKey: .reach)
        try c.encode(particles, forKey: .particles)
        try c.encode(temperature, forKey: .temperature)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(vignette, forKey: .vignette)
        try c.encode(shadow, forKey: .shadow)
        try c.encode(curl, forKey: .curl)
        try c.encode(fastener, forKey: .fastener)
    }

    // MARK: 白天 / 黑夜

    /// 换成白天或黑夜：光源和色温跟着换（白天窗户里的太阳光，夜里钨丝台灯）。
    mutating func setTime(_ new: TimeOfDay) {
        time = new
        setSource(new == .day ? .sunlight : .deskLamp)
    }

    mutating func setSource(_ new: LightSource) {
        source = new
        switch new {
        case .sunlight: temperature = 0.42
        case .deskLamp: temperature = 0.14
        case .moonlight: temperature = 0.88
        }
    }

    // MARK: 光

    /// 给灯光模型的摆法。
    var placement: LightPlacement {
        LightPlacement(source: source, x: lightX, y: lightY, reach: reach, softness: time == .day ? 0.35 : 0.55, intensity: intensity)
    }

    /// 屋里的环境光（乘在整块板子上，0…1）：白天亮，夜里只剩一点。
    var ambient: Double {
        switch source {
        case .sunlight: 0.9
        case .deskLamp: 0.4
        case .moonlight: 0.34
        }
    }

    /// 暗处偏什么颜色：白天带点暖褐，夜里是深蓝黑。
    var shadeRGB: (r: Double, g: Double, b: Double) {
        time == .day ? (0.18, 0.11, 0.05) : (0.02, 0.03, 0.09)
    }

    /// 光池（屏幕叠加）有多亮。
    var glowStrength: Double {
        switch source {
        case .sunlight: 0.36
        case .deskLamp: 0.32
        case .moonlight: 0.26
        }
    }

    /// 光池周围的泛光。
    var bloomOpacity: Double { time == .day ? 0.45 : 0.7 }

    /// 灰尘有多亮（夜里在光束里更显眼）。
    var particleStrength: Double { time == .day ? 0.55 : 0.85 }

    /// 指向光源的单位向量（屏幕坐标，y 向下）：从板子中间指向灯。
    var toLight: CGVector {
        let dx = lightX - 0.5
        let dy = lightY - 0.5
        let length = hypot(dx, dy)
        guard length > 0.04 else { return CGVector(dx: -0.7071, dy: -0.7071) }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// 阴影落下的方向（背着光）。
    var shadowDirection: CGVector {
        CGVector(dx: -toLight.dx, dy: -toLight.dy)
    }

    /// 光从哪个方向来（度，0 = 右，90 = 上，逆时针）。
    var angle: Double {
        let degrees = atan2(-toLight.dy, toLight.dx) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// 灯光颜色（0…1）：暖琥珀 → 中性暖白 → 冷月光。
    var lightRGB: (r: Double, g: Double, b: Double) {
        let warm = (r: 1.0, g: 0.78, b: 0.5)
        let neutral = (r: 1.0, g: 0.95, b: 0.86)
        let cool = (r: 0.78, g: 0.87, b: 1.0)
        let t = min(max(temperature, 0), 1)
        let (a, b, k) = t < 0.5 ? (warm, neutral, t / 0.5) : (neutral, cool, (t - 0.5) / 0.5)
        return (a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k)
    }

    var lightColor: Color {
        let c = lightRGB
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1)
    }

    /// 方向的说法（「左上」）。
    var directionName: String {
        let names = [String(localized: "右"), String(localized: "右上"), String(localized: "上"), String(localized: "左上"), String(localized: "左"), String(localized: "左下"), String(localized: "下"), String(localized: "右下")]
        return names[Int((angle + 22.5) / 45) % 8]
    }

    /// 灯的图标。
    var sourceSymbol: String {
        switch source {
        case .sunlight: "sun.max.fill"
        case .deskLamp: "lamp.desk.fill"
        case .moonlight: "moon.fill"
        }
    }

    /// 照片的阴影：偏移、模糊半径、不透明度（斜照的太阳把影子拉得长一点）。
    func dropShadow(lifted: Bool) -> (offset: CGSize, radius: CGFloat, opacity: Double) {
        let depth = 0.35 + shadow * 0.9 + (lifted ? 0.5 : 0)
        let distance = CGFloat(4 + 9 * depth) * (source == .sunlight ? 1.15 : 1)
        return (
            CGSize(width: shadowDirection.dx * distance, height: shadowDirection.dy * distance),
            CGFloat(6 + 10 * depth),
            0.1 + 0.2 * shadow + (lifted ? 0.08 : 0)
        )
    }

    /// 贴着板子的接触阴影。
    var contactShadow: (offset: CGSize, opacity: Double) {
        (CGSize(width: shadowDirection.dx * 1.2, height: shadowDirection.dy * 1.2), 0.18 + 0.18 * shadow)
    }
}

/// 软木板灯光设置的存取（UserDefaults）。
@MainActor
final class CorkLightingStore: ObservableObject {
    static let shared = CorkLightingStore()
    private static let key = "album.cork.lighting"

    @Published var lighting: CorkLighting {
        didSet {
            if let data = try? JSONEncoder().encode(lighting) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(CorkLighting.self, from: data) {
            lighting = saved
        } else {
            lighting = .standard
        }
    }

    func reset() {
        withAnimation(.easeInOut(duration: 0.35)) {
            lighting = .standard
        }
    }
}

// MARK: - 光照图与灰尘

/// 板子上的光，按灯光模型在 CPU 上以低分辨率算好（约 200 列，改了灯才重算），放大画上去：
/// - 暗处一层「影」（暗处的颜色，透明度 = 1 − 光量）：普通叠加，照片和软木一起被照亮、一起暗下去；
/// - 亮处一层「光」（灯光的颜色，屏幕叠加）和它模糊过的泛光；
/// - 光束里飘的灰尘（`DustMotes`，每粒按同一个模型点亮）。
struct CorkLightOverlay: View {
    let lighting: CorkLighting

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let maps = CorkLightMaps.shared.maps(for: lighting, size: size)
            ZStack {
                if let shade = maps.shade {
                    Image(decorative: shade, scale: 1)
                        .resizable()
                        .interpolation(.high)
                }
                if let glow = maps.glow {
                    Image(decorative: glow, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .blendMode(.screen)
                    Image(decorative: glow, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .blur(radius: max(8, min(size.width, size.height) * 0.04))
                        .opacity(lighting.bloomOpacity)
                        .blendMode(.screen)
                }
                if lighting.particles > 0.01 {
                    DustMotes(lighting: lighting, rig: maps.rig)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }
}

/// 算好的光照图（按灯光设置和尺寸缓存）。
@MainActor
final class CorkLightMaps {
    static let shared = CorkLightMaps()

    struct Maps {
        let shade: CGImage?
        let glow: CGImage?
        let rig: LightRig
    }

    private struct Key: Hashable {
        let lighting: CorkLighting
        let width: Int
        let height: Int
        let columns: Int
    }

    private var cache: [Key: Maps] = [:]

    func maps(for lighting: CorkLighting, size: CGSize, columns: Int = 200) -> Maps {
        let key = Key(lighting: lighting, width: Int(size.width.rounded()), height: Int(size.height.rounded()), columns: columns)
        if let cached = cache[key] { return cached }
        let maps = Self.render(lighting, size: size, columns: columns)
        if cache.count > 8 { cache.removeAll() }
        cache[key] = maps
        return maps
    }

    nonisolated static func render(_ lighting: CorkLighting, size: CGSize, columns: Int) -> Maps {
        let rig = LightModel.rig(lighting.placement, size: size)
        let width = max(1, Double(size.width))
        let height = max(1, Double(size.height))
        let cols = max(8, columns)
        let rows = max(6, Int((Double(cols) * height / width).rounded()))
        var shade = [UInt8](repeating: 0, count: cols * rows * 4)
        var glow = [UInt8](repeating: 0, count: cols * rows * 4)
        let ambient = lighting.ambient
        let tint = lighting.lightRGB
        let dark = lighting.shadeRGB
        let strength = lighting.glowStrength
        let vignette = lighting.vignette
        for j in 0..<rows {
            let v = (Double(j) + 0.5) / Double(rows)
            for i in 0..<cols {
                let u = (Double(i) + 0.5) / Double(cols)
                let lit = LightModel.lightAmount(rig, x: u * width, y: v * height)
                // 原版的暗角：离板子中间（略偏下）越远越暗。
                let corner = LightModel.smoothstep(0.15, 1.1, hypot(u - 0.5, (v - 0.55) * 1.15))
                let lightness = ambient * (1 - 0.45 * vignette * corner) + (1 - ambient) * lit
                let a = min(1, max(0, 1 - lightness))
                let g = min(1, max(0, lit * strength))
                let k = (j * cols + i) * 4
                shade[k] = UInt8(min(255, dark.r * a * 255))
                shade[k + 1] = UInt8(min(255, dark.g * a * 255))
                shade[k + 2] = UInt8(min(255, dark.b * a * 255))
                shade[k + 3] = UInt8(min(255, a * 255))
                glow[k] = UInt8(min(255, tint.r * g * 255))
                glow[k + 1] = UInt8(min(255, tint.g * g * 255))
                glow[k + 2] = UInt8(min(255, tint.b * g * 255))
                glow[k + 3] = UInt8(min(255, g * 255))
            }
        }
        return Maps(shade: image(shade, width: cols, height: rows), glow: image(glow, width: cols, height: rows), rig: rig)
    }

    private nonisolated static func image(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

/// 光束里飘的灰尘：每粒慢慢漂、一闪一闪，只在有光的地方看得见（亮度按灯光模型算）。
/// 移植自 Typewriter Nocturne 的 glow-layer.ts；每秒画 30 次。
private struct DustMotes: View {
    let lighting: CorkLighting
    let rig: LightRig

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            Canvas { context, size in
                let seconds = timeline.date.timeIntervalSince(DustMote.epoch)
                let count = Int((Double(DustMote.all.count) * min(1, max(0, lighting.particles))).rounded())
                let strength = lighting.particleStrength
                let tint = lighting.lightRGB
                let color = Color(.sRGB, red: tint.r, green: tint.g, blue: tint.b, opacity: 1)
                for mote in DustMote.all.prefix(count) {
                    let point = mote.position(at: seconds)
                    let x = point.x * size.width
                    let y = point.y * size.height
                    let lit = LightModel.lightAmount(rig, x: Double(x), y: Double(y))
                    guard lit > 0.05 else { continue }
                    let twinkle = 0.5 + 0.5 * sin(seconds * (0.8 + mote.z * 2.2) + mote.phase)
                    let radius = CGFloat(mote.size * (1 + mote.z * 1.6)) * 2
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    var dot = context
                    dot.opacity = min(1, lit * twinkle * strength)
                    dot.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(stops: [
                                .init(color: color, location: 0),
                                .init(color: color.opacity(0.6), location: 0.22),
                                .init(color: color.opacity(0), location: 1),
                            ]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .blendMode(.screen)
    }
}

/// 一粒灰尘（位置、深度、相位、大小都是固定的伪随机数）。
private struct DustMote {
    let x: Double
    let y: Double
    let z: Double
    let phase: Double
    let size: Double

    static let epoch = Date()

    private static func hash(_ n: Double) -> Double {
        let s = sin(n * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    static let all: [DustMote] = (0..<140).map { i in
        let n = Double(i)
        return DustMote(
            x: DustMote.hash(n * 3.1),
            y: DustMote.hash(n * 7.7),
            z: DustMote.hash(n * 1.9),
            phase: DustMote.hash(n * 5.3) * 100,
            size: 0.5 + DustMote.hash(n * 9.1) * 1.6
        )
    }

    /// 这一刻在板子上的位置（归一化）：左右慢慢漂，整体缓缓往上飘（暖空气往上走）。
    func position(at seconds: Double) -> CGPoint {
        let speed = 0.4 + z
        let drift = sin(seconds * 0.05 * speed + phase) * 0.04 + seconds * 0.004 * (z - 0.5)
        let fall = -seconds * 0.006 * speed + cos(seconds * 0.07 + phase) * 0.03
        return CGPoint(x: Self.wrap(x + drift), y: Self.wrap(y + fall))
    }

    private static func wrap(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 1)
        return r < 0 ? r + 1 : r
    }
}

// MARK: - 左下角的小铜牌

/// 钉在板子左下角的珐琅小铜牌「灯光」：点一下打开调节卡片。
struct LightBadge: View {
    let active: Bool
    let lighting: CorkLighting
    let action: () -> Void
    @State private var hovering = false

    init(active: Bool, lighting: CorkLighting, action: @escaping () -> Void) {
        self.active = active
        self.lighting = lighting
        self.action = action
    }

    var body: some View {
        let shadow = lighting.dropShadow(lifted: hovering)
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x8A6A35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFBF6EA), Color(hex: 0xEDE3CF)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 1, endRadius: 30))
                    .padding(4)
                VStack(spacing: 1) {
                    Image(systemName: lighting.sourceSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(active ? Palette.terracotta : Palette.ink.opacity(0.8))
                    Text("灯光")
                        .font(RetroFont.serif(10, weight: .semibold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                }
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                    .padding(4.5)
            }
            .frame(width: 54, height: 54)
            .overlay(alignment: .top) {
                Circle()
                    .fill(RadialGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x6E5228)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0.5, endRadius: 5))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.4), radius: 0.8, x: lighting.shadowDirection.dx * 1.5, y: lighting.shadowDirection.dy * 1.5)
                    .offset(y: 3)
            }
            .shadow(color: .black.opacity(lighting.contactShadow.opacity), radius: 1, x: lighting.contactShadow.offset.width, y: lighting.contactShadow.offset.height)
            .shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius * 0.6, x: shadow.offset.width * 0.6, y: shadow.offset.height * 0.6)
            .rotationEffect(.degrees(hovering ? -6 : -2), anchor: .top)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 7)) { hovering = inside }
        }
        .help("调节软木板的灯光与显示效果")
    }
}

// MARK: - 调节卡片

/// 一张打字机小卡片，两栏：左边白天 / 黑夜、光源、摆灯的小板子（拖铜钮挪灯，光斑当场画出来）、固定方式；
/// 右边亮度、范围、色温、灰尘、暗角、阴影、纸张卷曲。
struct LightingPanel: View {
    @ObservedObject var store: CorkLightingStore
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("灯光 · 显示")
                    .font(RetroFont.serif(15, weight: .semibold))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.paperDeep))
                }
                .buttonStyle(.plain)
                .help("收起")
            }
            .foregroundStyle(Palette.ink)
            Rectangle().fill(Palette.printRed.opacity(0.45)).frame(height: 0.8)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    TimeSwitch(lighting: $store.lighting)
                    if store.lighting.time == .night {
                        SourceChips(lighting: $store.lighting)
                            .transition(.opacity)
                    }
                    LightPad(lighting: $store.lighting)
                    Text("光从\(store.lighting.directionName)边来 · 拖动铜钮挪灯")
                        .font(RetroFont.typewriter(11))
                        .foregroundStyle(Palette.inkSoft)
                    fasteners
                }
                .frame(width: 212, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    PanelSlider(title: String(localized: "亮度"), value: $store.lighting.intensity, leading: String(localized: "暗"), trailing: String(localized: "亮"))
                    PanelSlider(title: String(localized: "范围"), value: $store.lighting.reach, leading: String(localized: "小"), trailing: String(localized: "大"))
                    PanelSlider(title: String(localized: "色温"), value: $store.lighting.temperature, leading: String(localized: "暖"), trailing: String(localized: "冷"),
                                groove: [Color(hex: 0xF2B46A), Color(hex: 0xFFF1DA), Color(hex: 0xCFE0F5)])
                    PanelSlider(title: String(localized: "灰尘"), value: $store.lighting.particles, leading: String(localized: "无"), trailing: String(localized: "多"))
                    PanelSlider(title: String(localized: "暗角"), value: $store.lighting.vignette, leading: String(localized: "无"), trailing: String(localized: "浓"))
                    PanelSlider(title: String(localized: "阴影"), value: $store.lighting.shadow, leading: String(localized: "浅"), trailing: String(localized: "深"))
                    PanelSlider(title: String(localized: "纸张卷曲"), value: $store.lighting.curl, leading: String(localized: "平"), trailing: String(localized: "卷"))
                }
                .frame(width: 236)
            }

            Button("恢复默认") { store.reset() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.terracotta)
        }
        .padding(16)
        .fixedSize()
        .background(
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0xFBF8F1), Color(hex: 0xF1EADC)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(Rectangle().stroke(Color.black.opacity(0.07), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.24), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(0.22), radius: 18, x: 5, y: 12)
        .rotationEffect(.degrees(-0.8))
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: store.lighting.time)
    }

    private var fasteners: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("固定方式")
                .font(RetroFont.typewriter(11.5))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 4) {
                ForEach(CorkLighting.Fastener.allCases) { style in
                    let selected = store.lighting.fastener == style
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            store.lighting.fastener = style
                        }
                    } label: {
                        Text(style.title)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(selected ? Color.white : Palette.ink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(selected ? Palette.terracotta : Palette.paperDeep))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 白天 / 黑夜：一对胶囊按钮（太阳、月亮）。
private struct TimeSwitch: View {
    @Binding var lighting: CorkLighting

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CorkLighting.TimeOfDay.allCases) { time in
                let selected = lighting.time == time
                Button {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        lighting.setTime(time)
                    }
                    SoundPlayer.shared.play(.gearClick)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: time.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(time.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(selected ? AnyShapeStyle(time == .day ? Palette.mustard : Palette.walnutDeep) : AnyShapeStyle(Palette.paperDeep))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Palette.ivoryShade.opacity(0.6)))
    }
}

/// 夜里的光源：台灯或月光。
private struct SourceChips: View {
    @Binding var lighting: CorkLighting

    var body: some View {
        HStack(spacing: 6) {
            chip(.deskLamp, title: String(localized: "台灯"), symbol: "lamp.desk.fill")
            chip(.moonlight, title: String(localized: "月光"), symbol: "moon.fill")
        }
    }

    private func chip(_ source: LightSource, title: String, symbol: String) -> some View {
        let selected = lighting.source == source
        return Button {
            withAnimation(.easeInOut(duration: 0.35)) {
                lighting.setSource(source)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? Color.white : Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(selected ? Palette.terracotta : Palette.paperDeep))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 摆灯的小板子：一块缩小的软木板，拖铜钮把灯（太阳、台灯、月亮）挪到想要的位置，光斑和窗格当场画出来。
private struct LightPad: View {
    @Binding var lighting: CorkLighting
    private let size = CGSize(width: 212, height: 118)

    var body: some View {
        let maps = CorkLightMaps.shared.maps(for: lighting, size: size, columns: 106)
        ZStack(alignment: .topLeading) {
            Color(hex: 0xC6A27B)
            if BundledImage.has("CorkSoft") {
                Image("CorkSoft")
                    .resizable(resizingMode: .tile)
                    .opacity(0.9)
            }
            if let shade = maps.shade {
                Image(decorative: shade, scale: 1)
                    .resizable()
                    .interpolation(.high)
            }
            if let glow = maps.glow {
                Image(decorative: glow, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .blendMode(.screen)
            }
            knob
                .position(x: lighting.lightX * size.width, y: lighting.lightY * size.height)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Palette.walnut, lineWidth: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.black.opacity(0.25), lineWidth: 0.6)
                .padding(3)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    lighting.lightX = Double(min(max(value.location.x / size.width, 0), 1))
                    lighting.lightY = Double(min(max(value.location.y / size.height, 0), 1))
                }
        )
        .help("灯的位置")
    }

    private var knob: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x6E5228)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0.5, endRadius: 12))
            Image(systemName: lighting.sourceSymbol)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Palette.walnutDeep)
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
    }
}

/// 复古滑杆：内凹的槽 + 黄铜钮。
private struct PanelSlider: View {
    let title: String
    @Binding var value: Double
    let leading: String
    let trailing: String
    var groove: [Color] = [Palette.ivoryShade, Palette.ivoryShade]

    init(title: String, value: Binding<Double>, leading: String, trailing: String, groove: [Color] = [Palette.ivoryShade, Palette.ivoryShade]) {
        self.title = title
        self._value = value
        self.leading = leading
        self.trailing = trailing
        self.groove = groove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(RetroFont.typewriter(11.5))
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                Text("\(leading) · \(trailing)")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkSoft.opacity(0.7))
            }
            GeometryReader { geo in
                let width = geo.size.width
                let x = CGFloat(min(max(value, 0), 1)) * (width - 14) + 7
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: groove, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                        .overlay(Capsule().stroke(Color.black.opacity(0.18), lineWidth: 0.6))
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                    Circle()
                        .fill(RadialGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x6E5228)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0.5, endRadius: 9))
                        .frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.35), radius: 1.2, y: 1)
                        .position(x: x, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            value = Double(min(max((drag.location.x - 7) / max(width - 14, 1), 0), 1))
                        }
                )
            }
            .frame(height: 18)
        }
    }
}
