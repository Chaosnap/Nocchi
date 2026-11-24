import AppKit
import SwiftUI

/// 软木板的灯光与显示设置：板子左下角钉着的小铜牌打开调节卡片，设置会记住。
struct CorkLighting: Codable, Equatable {
    enum Fastener: String, Codable, CaseIterable, Identifiable {
        case mixed
        case brass
        case mapPin
        case tape
        case clip

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mixed: "混搭"
            case .brass: "黄铜钉"
            case .mapPin: "地图针"
            case .tape: "胶带"
            case .clip: "木夹"
            }
        }
    }

    /// 光从哪个方向来（度，0 = 右，90 = 上，135 = 左上，逆时针）。
    var angle: Double = 135
    /// 色温：0 = 暖（钨丝台灯），0.5 = 中性，1 = 冷（北窗日光）。
    var temperature: Double = 0.3
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

    /// 指向光源的单位向量（屏幕坐标，y 向下）。
    var toLight: CGVector {
        let radians = angle * .pi / 180
        return CGVector(dx: cos(radians), dy: -sin(radians))
    }

    /// 阴影落下的方向（背着光）。
    var shadowDirection: CGVector {
        CGVector(dx: -toLight.dx, dy: -toLight.dy)
    }

    /// 灯光颜色：暖琥珀 → 中性暖白 → 冷白。
    var lightColor: Color {
        let warm = (r: 1.0, g: 0.80, b: 0.55)
        let neutral = (r: 1.0, g: 0.95, b: 0.86)
        let cool = (r: 0.86, g: 0.92, b: 1.0)
        let t = min(max(temperature, 0), 1)
        let (a, b, k) = t < 0.5 ? (warm, neutral, t / 0.5) : (neutral, cool, (t - 0.5) / 0.5)
        return Color(.sRGB, red: a.r + (b.r - a.r) * k, green: a.g + (b.g - a.g) * k, blue: a.b + (b.b - a.b) * k, opacity: 1)
    }

    /// 方向的中文说法（「左上」）。
    var directionName: String {
        let names = ["右", "右上", "上", "左上", "左", "左下", "下", "右下"]
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized + 22.5) / 45) % 8]
    }

    /// 照片的阴影：偏移、模糊半径、不透明度。
    func dropShadow(lifted: Bool) -> (offset: CGSize, radius: CGFloat, opacity: Double) {
        let depth = 0.35 + shadow * 0.9 + (lifted ? 0.5 : 0)
        let distance = CGFloat(4 + 9 * depth)
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
                    Image(systemName: "lamp.desk.fill")
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

/// 一张打字机小卡片：光的方向（黄铜拨盘）、色温、亮度、暗角、阴影、纸张卷曲、固定方式。
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

            HStack(alignment: .center, spacing: 14) {
                AngleDial(angle: $store.lighting.angle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("光从\(store.lighting.directionName)边来")
                        .font(RetroFont.typewriter(12))
                        .foregroundStyle(Palette.ink)
                    Text("拖动铜钮转台灯")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.inkSoft)
                }
            }

            PanelSlider(title: "色温", value: $store.lighting.temperature, leading: "暖", trailing: "冷",
                        groove: [Color(hex: 0xF2B46A), Color(hex: 0xFFF1DA), Color(hex: 0xCFE0F5)])
            PanelSlider(title: "亮度", value: $store.lighting.intensity, leading: "暗", trailing: "亮")
            PanelSlider(title: "暗角", value: $store.lighting.vignette, leading: "无", trailing: "浓")
            PanelSlider(title: "阴影", value: $store.lighting.shadow, leading: "浅", trailing: "深")
            PanelSlider(title: "纸张卷曲", value: $store.lighting.curl, leading: "平", trailing: "卷")

            VStack(alignment: .leading, spacing: 6) {
                Text("固定方式")
                    .font(RetroFont.typewriter(11.5))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 5) {
                    ForEach(CorkLighting.Fastener.allCases) { style in
                        let selected = store.lighting.fastener == style
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                store.lighting.fastener = style
                            }
                        } label: {
                            Text(style.title)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Color.white : Palette.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(selected ? Palette.terracotta : Palette.paperDeep))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("恢复默认") { store.reset() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.terracotta)
        }
        .padding(16)
        .frame(width: 300)
        .background(
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0xFBF8F1), Color(hex: 0xF1EADC)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(Rectangle().stroke(Color.black.opacity(0.07), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.24), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(0.22), radius: 18, x: 5, y: 12)
        .rotationEffect(.degrees(-0.8))
    }
}

/// 黄铜拨盘：一圈刻度，拖动铜钮转动光的方向。
private struct AngleDial: View {
    @Binding var angle: Double
    private let size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.paperDeep.shadow(.inner(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 1)))
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(Palette.ink.opacity(index % 3 == 0 ? 0.5 : 0.22))
                    .frame(width: 1, height: index % 3 == 0 ? 6 : 4)
                    .offset(y: -size / 2 + 6)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
                .foregroundStyle(Palette.mustard)
                .offset(knobOffset(radius: size / 2 - 17))
            Circle()
                .fill(RadialGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x6E5228)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0.5, endRadius: 8))
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.35), radius: 1.2, y: 1)
                .offset(knobOffset(radius: size / 2 - 7))
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.location.x - size / 2
                    let dy = value.location.y - size / 2
                    guard hypot(dx, dy) > 4 else { return }
                    var degrees = atan2(-dy, dx) * 180 / .pi
                    if degrees < 0 { degrees += 360 }
                    angle = (degrees / 5).rounded() * 5
                }
        )
        .help("光的方向")
    }

    private func knobOffset(radius: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: cos(radians) * radius, height: -sin(radians) * radius)
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
