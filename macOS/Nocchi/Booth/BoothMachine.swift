import AVFoundation
import NocchiKit
import SwiftUI

/// 大头贴机整机：Blender 一体建模的正面（`design/blender/booth/make_machine.py` → `BoothMachine`，720 × 960 点）——
/// 拱顶灯泡招牌、胡桃木机身与凹槽立柱、镀铬包边的橱窗、黄铜铭牌、奶油色搪瓷控制台、出片口与投币口。
///
/// 黄铜铭牌上是阳刻的鎏金字「Nocchi」（建模的一部分）。
/// 橱窗是透明的：选相框时里面挂着这一款的样张（相框名写在角落的小标签上），拍照时是摄像头画面。黄铜箭头、拨杆、开始按钮是同一场景里
/// 单独渲染的零件图（抬起 / 按下、左 / 右、暗 / 亮），按 `BoothMachineLayout` 叠在整机上；招牌一圈的灯泡在这里做跑马灯。
struct BoothMachine: View {
    @ObservedObject var booth: PhotoBoothController
    @ObservedObject var previews: TemplatePreviewStore
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    /// 渲染图在不在（缺图时大头贴机退回画出来的那一版）。
    static var isAvailable: Bool { BundledImage.has("BoothMachine") }

    /// 整机图：英文界面用招牌和刻字是英文的那张（`make_machine.py --english`），没有时用中文的。
    static var baseImage: String {
        UILanguage.current.isEnglish && BundledImage.has("BoothMachineEN") ? "BoothMachineEN" : "BoothMachine"
    }

    private typealias L = BoothMachineLayout

    private var choosing: Bool { booth.phase == .choosingFrame || booth.phase == .closingCurtain }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MachineWindow(booth: booth, previews: previews, session: session, camera: camera, choosing: choosing)
                .frame(width: L.window.width, height: L.window.height)
                .clipShape(RoundedRectangle(cornerRadius: L.windowCornerRadius, style: .continuous))
                .offset(x: L.window.minX, y: L.window.minY)

            Image(Self.baseImage)
                .resizable()
                .interpolation(.high)
                .frame(width: L.size.width, height: L.size.height)
                .allowsHitTesting(false)

            MarqueeLights()
                .frame(width: L.size.width, height: L.size.height)
                .allowsHitTesting(false)

            SlotLights(booth: booth, choosing: choosing)
                .frame(width: L.dots.width, height: L.dots.height)
                .offset(x: L.dots.minX, y: L.dots.minY)

            Text("胶卷 · \(booth.stock.name)")
                .font(RetroFont.typewriter(11.5))
                .foregroundStyle(Color(hex: 0x5A4A3C))
                .frame(width: L.filmInfo.width, height: L.filmInfo.height)
                .offset(x: L.filmInfo.minX, y: L.filmInfo.minY)

            MachineControls(booth: booth, choosing: choosing)
                .frame(width: L.size.width, height: L.size.height, alignment: .topLeading)
        }
        .frame(width: L.size.width, height: L.size.height, alignment: .topLeading)
        // 连贯的两层阴影：贴地的接触阴影 + 柔和的大投影（形状跟着拱顶走，没有直角）。
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
        .shadow(color: .black.opacity(0.45), radius: 36, x: 0, y: 22)
        .task(id: "\(booth.boothFormat.rawValue)|\(booth.stock.id)") {
            await previews.prefetch(booth.prefetchRequests())
        }
    }
}

// MARK: - 橱窗

/// 橱窗里面：选相框时是挂着样张的深色绒布橱窗，拍照时是摄像头画面（按所选版式画出取景范围）。
private struct MachineWindow: View {
    @ObservedObject var booth: PhotoBoothController
    @ObservedObject var previews: TemplatePreviewStore
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService
    let choosing: Bool

    var body: some View {
        ZStack {
            if choosing {
                ShowcaseInterior(booth: booth, previews: previews)
                    .transition(.opacity)
            } else {
                CameraInterior(booth: booth, session: session, camera: camera)
                    .transition(.opacity)
            }
            // 玻璃：一道斜反光 + 四周的内凹阴影（镀铬框在整机图上）。
            LinearGradient(colors: [.white.opacity(0.10), .clear, .clear, .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: BoothMachineLayout.windowCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.6), lineWidth: 10)
                .blur(radius: 8)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.35), value: choosing)
    }
}

/// 选相框：深色绒布 + 顶上一盏暖灯，样张用小铜夹挂着；换相框时从切换的方向滑进来。
private struct ShowcaseInterior: View {
    @ObservedObject var booth: PhotoBoothController
    @ObservedObject var previews: TemplatePreviewStore

    private let maxPrint = CGSize(width: 380, height: 318)

    var body: some View {
        let request = booth.previewRequest(for: booth.selectedTemplate)
        let key = "\(booth.selectedTemplate.id)|\(booth.boothFormat.rawValue)|\(request.stockID)"
        ZStack {
            LinearGradient(colors: [Color(hex: 0x3A2620), Color(hex: 0x1A100D)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0xFFE2B8, opacity: 0.34), .clear], center: UnitPoint(x: 0.45, y: 0.0), startRadius: 6, endRadius: 330)
            sample(previews.image(request))
                .id(key)
                .transition(.asymmetric(
                    insertion: .offset(x: CGFloat(booth.lastStep) * 90).combined(with: .opacity),
                    removal: .offset(x: CGFloat(-booth.lastStep) * 90).combined(with: .opacity)
                ))
            // 角落里一张小标签：相框名和一句说明（像橱窗里展品的说明卡）。
            VStack {
                Spacer()
                HStack {
                    TemplateLabel(name: booth.selectedTemplate.name, note: booth.selectedTemplate.note)
                        .id(booth.selectedTemplate.id)
                        .transition(.opacity)
                    Spacer()
                }
            }
            .padding(18)
            .animation(.easeInOut(duration: 0.25), value: booth.selectedTemplate.id)
        }
    }

    private func printSize(_ format: FilmFormat) -> CGSize {
        let aspect = format.layout.aspect
        var height = maxPrint.height
        var width = height * aspect
        if width > maxPrint.width {
            width = maxPrint.width
            height = width / aspect
        }
        return CGSize(width: width, height: height)
    }

    @ViewBuilder
    private func sample(_ image: CGImage?) -> some View {
        let size = printSize(booth.boothFormat)
        ZStack(alignment: .top) {
            Group {
                if let image {
                    Image(decorative: image, scale: 2)
                        .resizable()
                        .interpolation(.high)
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Palette.paperDeep.opacity(0.85))
                }
            }
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(0.45), radius: 1.5, x: 0.5, y: 1)
            .shadow(color: .black.opacity(0.35), radius: 16, x: 4, y: 12)

            BrassClip()
                .offset(y: -9)
        }
        .rotationEffect(.degrees(-1.2))
        .offset(y: 10)
    }
}

/// 拍照：摄像头画面铺满橱窗，按版式画出这一格的取景范围；倒数和「请看镜头」叠在上面。
private struct CameraInterior: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    var body: some View {
        GeometryReader { geo in
            let guide = guideSize(in: geo.size)
            ZStack {
                Color.black
                CameraPreview(session: session, mirrored: true, isRunning: camera.isRunning)
                // 取景范围以外压暗一点。
                Rectangle()
                    .fill(Color.black.opacity(0.38))
                    .mask(
                        ZStack {
                            Rectangle()
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .frame(width: guide.width, height: guide.height)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    .frame(width: guide.width, height: guide.height)
                if !camera.isRunning {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("正在打开摄像头…")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .offset(y: 70)
                }
                PhaseOverlay(phase: booth.phase)
                    .scaleEffect(0.8)
                VStack {
                    Spacer()
                    StatusPill(booth: booth)
                }
                .padding(.bottom, 14)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// 一格的取景范围（四格条每格 4:3，四宫格每格 3:4），尽量大地放进橱窗。
    private func guideSize(in size: CGSize) -> CGSize {
        let aspect = booth.boothFormat.layout.windowAspect
        let inset = CGSize(width: size.width - 36, height: size.height - 36)
        var width = inset.width
        var height = width / aspect
        if height > inset.height {
            height = inset.height
            width = height * aspect
        }
        return CGSize(width: width, height: height)
    }
}

// MARK: - 标签、页码槽、灯泡

/// 橱窗角落的展品说明卡：宋体相框名 + 打字机字的一句说明，微微歪着，有一点投影。
private struct TemplateLabel: View {
    let name: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(RetroFont.serif(15, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(note)
                .font(RetroFont.typewriter(10))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 118, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFBF6EC), Color(hex: 0xEFE5D2)], startPoint: .top, endPoint: .bottom))
        )
        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
        .shadow(color: .black.opacity(0.28), radius: 7, x: 2, y: 5)
        .rotationEffect(.degrees(-1.5))
    }
}

/// 拍照时橱窗下沿的进度：「请看镜头」「第 2 张 · 共 4 张」「冲印中」。
private struct StatusPill: View {
    @ObservedObject var booth: PhotoBoothController

    private var text: String? {
        switch booth.phase {
        case .lookHere: return String(localized: "请看镜头")
        case .countdown, .flash, .pause: return String(localized: "第 \(min(booth.shot + 1, booth.totalShots)) 张 · 共 \(booth.totalShots) 张")
        case .openingCurtain: return String(localized: "冲印中")
        default: return nil
        }
    }

    var body: some View {
        if let text {
            Text(text)
                .font(RetroFont.typewriter(12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .id(text)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: text)
        }
    }
}

/// 黑色页码槽里的小灯：选相框时一颗一颗是相框（亮的是这一款，点一下跳过去），拍照时四格进度。
private struct SlotLights: View {
    @ObservedObject var booth: PhotoBoothController
    let choosing: Bool

    var body: some View {
        HStack(spacing: choosing ? 8 : 16) {
            if choosing {
                ForEach(0..<booth.templates.count, id: \.self) { index in
                    lamp(on: index == booth.templateIndex)
                        .frame(width: 12, height: 10)
                        .contentShape(Rectangle())
                        .onTapGesture { booth.select(index: index) }
                }
            } else {
                ForEach(0..<booth.totalShots, id: \.self) { index in
                    lamp(on: index < booth.shot || (index == booth.shot && booth.phase == .pause))
                        .frame(width: 14, height: 10)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: booth.templateIndex)
    }

    private func lamp(on: Bool) -> some View {
        Circle()
            .fill(on
                  ? RadialGradient(colors: [Color(hex: 0xFFE6B0), Color(hex: 0xF0A04A)], center: .center, startRadius: 0.5, endRadius: 4)
                  : RadialGradient(colors: [Color(hex: 0x4A3A2A), Color(hex: 0x241A12)], center: .center, startRadius: 0.5, endRadius: 4))
            .frame(width: on ? 6 : 5, height: on ? 6 : 5)
            .shadow(color: on ? Color(hex: 0xFFB45A, opacity: 0.9) : .clear, radius: on ? 4 : 0)
    }
}

/// 招牌一圈灯泡的跑马灯：每三颗亮一颗，依次往前跑。
private struct MarqueeLights: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.42)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.42)
            ZStack(alignment: .topLeading) {
                ForEach(Array(BoothMachineLayout.bulbs.enumerated()), id: \.offset) { item in
                    let lit = (item.offset + step) % 3 == 0
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: 0xFFF4D6, opacity: lit ? 0.95 : 0.4), Color(hex: 0xFFB45A, opacity: lit ? 0.55 : 0.12), .clear],
                            center: .center,
                            startRadius: 1,
                            endRadius: 15
                        ))
                        .frame(width: 30, height: 30)
                        .position(item.element)
                        .blendMode(.screen)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: step)
        }
    }
}

// MARK: - 按钮与拨杆

/// 黄铜箭头、两个拨杆、开始按钮（零件图按整机坐标摆放）；点拨杆两边的刻字拨到那一边。
private struct MachineControls: View {
    @ObservedObject var booth: PhotoBoothController
    let choosing: Bool
    @State private var glow = false

    private typealias L = BoothMachineLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            part(L.arrowLeft) {
                Button { booth.step(-1) } label: { EmptyView() }
                    .buttonStyle(MachinePartStyle(up: "BoothMachineArrowLeft", down: "BoothMachineArrowLeftDown"))
                    .help("上一款（←）")
            }
            part(L.arrowRight) {
                Button { booth.step(1) } label: { EmptyView() }
                    .buttonStyle(MachinePartStyle(up: "BoothMachineArrowRight", down: "BoothMachineArrowRightDown"))
                    .help("下一款（→）")
            }

            lever(
                isRight: booth.boothFormat == .boothGrid,
                left: (L.formatLeft, "BoothMachineFormatLeft"),
                right: (L.formatRight, "BoothMachineFormatRight")
            ) { right in
                booth.setFormat(right ? .boothGrid : .boothStrip)
            }
            .help("四格条 / 四宫格（↑ ↓）")
            lever(
                isRight: !booth.monochrome,
                left: (L.colorLeft, "BoothMachineColorLeft"),
                right: (L.colorRight, "BoothMachineColorRight")
            ) { right in
                booth.setMonochrome(!right)
            }
            .help("黑白 / 彩色")

            labelTarget("四格条") { booth.setFormat(.boothStrip) } // i18n-ok：BoothMachineLayout.labels 的键
            labelTarget("四宫格") { booth.setFormat(.boothGrid) } // i18n-ok：BoothMachineLayout.labels 的键
            labelTarget("黑白") { booth.setMonochrome(true) } // i18n-ok：BoothMachineLayout.labels 的键
            labelTarget("彩色") { booth.setMonochrome(false) } // i18n-ok：BoothMachineLayout.labels 的键

            part(L.start) {
                Button { booth.confirmFrame() } label: { EmptyView() }
                    .buttonStyle(StartPartStyle(glowing: choosing ? glow : true, labelOffset: CGSize(
                        width: L.startCenter.x - L.start.midX,
                        height: L.startCenter.y - L.start.midY
                    )))
                    .help("投币开始（Return）")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func part<Content: View>(_ rect: CGRect, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// 拨杆：左右两张渲染图交叉淡入淡出，点拨杆来回拨。
    private func lever(isRight: Bool, left: (CGRect, String), right: (CGRect, String), change: @escaping (Bool) -> Void) -> some View {
        let union = left.0.union(right.0)
        return ZStack(alignment: .topLeading) {
            Image(left.1)
                .resizable()
                .interpolation(.high)
                .frame(width: left.0.width, height: left.0.height)
                .offset(x: left.0.minX - union.minX, y: left.0.minY - union.minY)
                .opacity(isRight ? 0 : 1)
            Image(right.1)
                .resizable()
                .interpolation(.high)
                .frame(width: right.0.width, height: right.0.height)
                .offset(x: right.0.minX - union.minX, y: right.0.minY - union.minY)
                .opacity(isRight ? 1 : 0)
        }
        .frame(width: union.width, height: union.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { change(!isRight) }
        .animation(.easeOut(duration: 0.08), value: isRight)
        .offset(x: union.minX, y: union.minY)
    }

    /// 刻字上的透明热区。
    private func labelTarget(_ name: String, action: @escaping () -> Void) -> some View {
        let center = L.labels[name] ?? .zero
        return Color.clear
            .frame(width: 58, height: 30)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .offset(x: center.x - 29, y: center.y - 15)
    }
}

/// 零件按钮：抬起 / 按下两张渲染图。
private struct MachinePartStyle: ButtonStyle {
    let up: String
    let down: String

    func makeBody(configuration: Configuration) -> some View {
        Image(configuration.isPressed ? down : up)
            .resizable()
            .interpolation(.high)
            .contentShape(Circle())
    }
}

/// 开始按钮：暗 / 亮两张图交叠呼吸，按下换成按下去的那张；「开 始」印在灯罩上。
private struct StartPartStyle: ButtonStyle {
    let glowing: Bool
    let labelOffset: CGSize

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if configuration.isPressed {
                Image("BoothMachineStartDown")
                    .resizable()
                    .interpolation(.high)
            } else {
                Image("BoothMachineStart")
                    .resizable()
                    .interpolation(.high)
                Image("BoothMachineStartLit")
                    .resizable()
                    .interpolation(.high)
                    .opacity(glowing ? 1 : 0)
            }
            Text("开 始")
                .font(RetroFont.serif(18, weight: .bold))
                .foregroundStyle(Palette.ivoryLight)
                .shadow(color: Color(hex: 0x6A1A10, opacity: 0.85), radius: 0, x: 0, y: 1)
                .offset(x: labelOffset.width, y: labelOffset.height + (configuration.isPressed ? 1.5 : 0))
        }
        .shadow(color: Color(hex: 0xFF6A4A, opacity: glowing && !configuration.isPressed ? 0.55 : 0.12), radius: glowing ? 20 : 8)
        .contentShape(Circle())
    }
}
