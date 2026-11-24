import AppKit
import AVFoundation
import NocchiKit
import SwiftUI

/// 可以成为 key window 的无边框窗口（接收 Esc）。
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 大头贴机「选相框」里选好的东西：版式（四格条 / 四宫格）、相框（模板）和这一条用的胶卷。
struct BoothSetup: Equatable {
    var format: FilmFormat
    var templateID: String
    var stockID: String
}

/// 大头贴机：先拿到摄像头权限 → 拉帘 → 选相框（相框、版式、黑白 / 彩色）→ 投币「开始」→ 请看镜头 →
/// 3、2、1 → 白屏闪光 × 4 → 拉开帘子 → 从刘海出片。
///
/// 任何情况下都能离开：权限在显示布帘之前就问好；布帘窗口在菜单栏之下（菜单栏里的「退出」始终可点）；
/// 有「离开」按钮、Esc、⌘Q；拍照有超时；按下「开始」之后有看门狗（选相框时不计时，慢慢挑）。
@MainActor
final class PhotoBoothController: ObservableObject {
    static let shared = PhotoBoothController()

    enum Phase: Equatable {
        case idle
        case closingCurtain
        case choosingFrame
        case lookHere
        case countdown(Int)
        case flash
        case pause
        case openingCurtain
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var shot = 0
    @Published private(set) var curtainDown: CGFloat = 0

    // 选相框
    @Published private(set) var boothFormat: FilmFormat = .boothStrip
    @Published private(set) var templates: [PrintTemplate] = []
    @Published private(set) var templateIndex = 0
    @Published private(set) var monochrome = false
    /// 上一次换相框的方向（+1 往右、-1 往左），样张按这个方向滑进来。
    @Published private(set) var lastStep = 1
    let previews = TemplatePreviewStore()

    let totalShots = 4
    let curtain = CurtainScene()

    private var window: KeyableWindow?
    private var task: Task<Void, Never>?
    private var keyMonitor: Any?
    private var session = 0
    private var isPreparing = false

    var isActive: Bool { phase != .idle || isPreparing }

    var selectedTemplate: PrintTemplate {
        templates.indices.contains(templateIndex) ? templates[templateIndex] : TemplateCatalog.classic
    }

    /// 这一条用的胶卷（黑白 / 彩色开关 + 装着的胶卷）。
    var stock: FilmStock {
        AppModel.shared.boothStock(monochrome: monochrome)
    }

    private init() {}

    func start() {
        guard !isActive, NotchController.shared.mode != .selfie else { return }
        isPreparing = true
        NotchController.shared.collapse()
        Task {
            // 1. 先拿权限：此时屏幕上没有任何 Nocchi 覆盖层，系统弹窗一定点得到。
            let granted = await CameraAccess.ensure()
            self.isPreparing = false
            guard granted else {
                CameraAccess.presentDeniedAlert()
                return
            }
            guard let screen = NotchController.shared.targetScreen, self.phase == .idle else { return }
            self.session += 1
            let current = self.session
            self.loadChoices()
            self.phase = .closingCurtain
            self.shot = 0
            self.showWindow(on: screen)
            self.task = Task { await self.closeCurtain(session: current) }
        }
    }

    /// 立刻离开（不等拍摄流程结束）。
    func cancel() {
        guard phase != .idle else { return }
        session += 1
        task?.cancel()
        CameraService.shared.stop()
        teardown()
    }

    // MARK: - 选相框

    /// 截图工作室用：不要权限、不开摄像头、不显示布帘窗口，直接停在「选相框」。
    func showcaseFrameChooser() {
        guard phase == .idle, !isPreparing else { return }
        loadChoices()
        curtainDown = 1
        phase = .choosingFrame
    }

    /// 结束 `showcaseFrameChooser()`。
    func endShowcase() {
        guard window == nil else { return }
        phase = .idle
        curtainDown = 0
        previews.removeAll()
    }

    /// 从上次的选择开始（设置里的默认相框、版式、黑白）。
    private func loadChoices() {
        let model = AppModel.shared
        boothFormat = FilmFormat.boothChoices.contains(model.boothFormat) ? model.boothFormat : .boothStrip
        templates = TemplateCatalog.boothTemplates(for: boothFormat)
        templateIndex = templates.firstIndex { $0.id == model.defaultBoothTemplateID } ?? 0
        monochrome = model.boothMonochrome
        lastStep = 1
    }

    /// 换一款相框（← →）。
    func step(_ delta: Int) {
        guard phase == .choosingFrame, !templates.isEmpty else { return }
        lastStep = delta >= 0 ? 1 : -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            templateIndex = (templateIndex + delta % templates.count + templates.count) % templates.count
        }
        Sound.play(.gearClick)
        Haptics.tick()
    }

    /// 直接选第 index 款（点页码圆点）。
    func select(index: Int) {
        guard phase == .choosingFrame, templates.indices.contains(index), index != templateIndex else { return }
        lastStep = index > templateIndex ? 1 : -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            templateIndex = index
        }
        Sound.play(.gearClick)
    }

    /// 四格条 / 四宫格（同一款相框两种版式都有，切换时留在这一款）。
    func setFormat(_ format: FilmFormat) {
        guard phase == .choosingFrame, format != boothFormat, FilmFormat.boothChoices.contains(format) else { return }
        let currentID = selectedTemplate.id
        let list = TemplateCatalog.boothTemplates(for: format)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            boothFormat = format
            templates = list
            templateIndex = list.firstIndex { $0.id == currentID } ?? 0
        }
        Sound.play(.magnet)
        Haptics.tick()
    }

    func setMonochrome(_ value: Bool) {
        guard phase == .choosingFrame, value != monochrome else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            monochrome = value
        }
        Sound.play(.magnet)
        Haptics.tick()
    }

    /// 预览请求：橱窗里的样张高约 270pt，按 620px 高合成（Retina 上也清楚）。
    func previewRequest(for template: PrintTemplate) -> TemplatePreviewStore.Request {
        let widthPixels = Int((620 * boothFormat.layout.aspect).rounded())
        return .current(templateID: template.id, format: boothFormat, stockID: stock.id, widthPixels: widthPixels)
    }

    /// 先合成正在看的这款，再由近及远合成其余的。
    func prefetchRequests() -> [TemplatePreviewStore.Request] {
        let count = templates.count
        guard count > 0 else { return [] }
        var order: [Int] = [templateIndex]
        for distance in 1..<max(count, 1) {
            for index in [(templateIndex + distance) % count, (templateIndex - distance % count + count) % count] where !order.contains(index) {
                order.append(index)
            }
        }
        return order.map { previewRequest(for: templates[$0]) }
    }

    /// 「开始」：投币，记住这次的选择，进入拍摄。看门狗从这里开始计时。
    func confirmFrame() {
        guard phase == .choosingFrame else { return }
        let current = session
        let setup = BoothSetup(format: boothFormat, templateID: selectedTemplate.id, stockID: stock.id)
        let model = AppModel.shared
        model.boothFormat = setup.format
        model.defaultBoothTemplateID = setup.templateID
        model.boothMonochrome = monochrome
        Sound.play(.coin)
        Haptics.heavy()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            phase = .lookHere
        }
        task = Task { await self.shoot(session: current, setup: setup) }
        // 看门狗：按下「开始」后 60 秒还没拍完就强制收起。
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            if self.session == current, self.phase != .idle, self.phase != .choosingFrame {
                self.cancel()
                NotchController.shared.showToast(String(localized: "大头贴机超时了，已经收起"), symbol: "exclamationmark.triangle.fill")
            }
        }
    }

    // MARK: - 拍摄

    /// 拉上帘子，然后停在「选相框」。
    private func closeCurtain(session current: Int) async {
        do {
            Sound.play(.curtain)
            curtain.drop(duration: 0.9)
            withAnimation(.easeInOut(duration: 0.9)) { curtainDown = 1 }
            try await pause(0.95)
            try checkSession(current)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                phase = .choosingFrame
            }
        } catch {
            guard session == current else { return }
            teardown()
        }
    }

    private func shoot(session current: Int, setup: BoothSetup) async {
        let camera = CameraService.shared
        var frames: [CGImage] = []
        do {
            try await pause(0.35)
            try await camera.start()
            try checkSession(current)
            try await pause(1.3)
            for index in 0..<totalShots {
                try checkSession(current)
                shot = index
                for n in [3, 2, 1] {
                    phase = .countdown(n)
                    Sound.play(n == 1 ? .beepFinal : .beep)
                    try await pause(0.72)
                }
                phase = .flash
                Sound.play(.shutterBooth)
                Haptics.heavy()
                try await pause(0.07)
                if let image = try? await camera.capture(timeout: 4) {
                    frames.append(image)
                }
                try await pause(0.16)
                phase = .pause
                try await pause(index < totalShots - 1 ? 1.5 : 0.4)
            }
            camera.stop()
            phase = .openingCurtain
            Sound.play(.curtain)
            curtain.raise(duration: 0.8)
            withAnimation(.easeInOut(duration: 0.8)) { curtainDown = 0 }
            try await pause(0.85)
        } catch {
            guard session == current else { return }
            camera.stop()
            teardown()
            if !(error is CancellationError) {
                NotchController.shared.showToast(CameraService.describe(error), symbol: "video.slash.fill", duration: 3.5)
            }
            return
        }
        guard session == current else { return }
        teardown()
        guard !frames.isEmpty else {
            NotchController.shared.showToast(String(localized: "大头贴没拍到，再来一次"), symbol: "exclamationmark.triangle.fill")
            return
        }
        // 少拍了的格子用最后一张补上（不能重拍，就是这么任性）。
        while frames.count < totalShots, let last = frames.last {
            frames.append(last)
        }
        await Darkroom.shared.develop(frames, source: .booth, body: .photoBooth, mirror: true, booth: setup)
    }

    private func checkSession(_ current: Int) throws {
        if session != current || Task.isCancelled { throw CancellationError() }
    }

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func showWindow(on screen: NSScreen) {
        let window = KeyableWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // 在菜单栏之下：菜单栏里的 Nocchi →「退出」永远点得到，系统弹窗也不会被挡住。
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
        curtain.build(screen: screen.frame.size, gap: 780)
        let host = NSHostingView(rootView: BoothCurtainView(booth: self, session: CameraService.shared.session, camera: CameraService.shared).scrollIndicators(.never))
        host.sizingOptions = []
        window.contentView = host
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return event }
                if event.keyCode == 53 {
                    self.cancel()
                    return nil
                }
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "q" {
                    self.cancel()
                    NSApp.terminate(nil)
                    return nil
                }
                guard self.phase == .choosingFrame else { return event }
                switch event.keyCode {
                case 123: self.step(-1)                       // ←
                case 124: self.step(1)                        // →
                case 125, 126:                                // ↓ ↑
                    self.setFormat(self.boothFormat == .boothStrip ? .boothGrid : .boothStrip)
                case 36, 76: self.confirmFrame()              // Return / Enter
                default: return event
                }
                return nil
            }
        }
    }

    private func teardown() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        window?.orderOut(nil)
        window = nil
        curtainDown = 0
        phase = .idle
        task = nil
        previews.removeAll()
    }
}

/// 布帘（3D）、选相框 / 取景框、倒数、闪光，以及始终可见的「离开」按钮。
struct BoothCurtainView: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.62 * booth.curtainDown)

                // 布帘在机身后面：招牌在帘头前面，机身两边盖住帘子的里缘。
                CurtainSceneView(curtain: booth.curtain)
                    .allowsHitTesting(false)

                BoothInterior(booth: booth, session: session, camera: camera)
                    .opacity(Double(booth.curtainDown))
                    .scaleEffect((0.96 + 0.04 * booth.curtainDown) * Self.fitScale(geo.size))

                Color.white
                    .opacity(booth.phase == .flash ? 1 : 0)
                    .animation(.easeOut(duration: booth.phase == .flash ? 0.04 : 0.35), value: booth.phase)
                    .allowsHitTesting(false)

                VStack {
                    HStack {
                        Button {
                            booth.cancel()
                        } label: {
                            Label("离开大头贴机", systemImage: "xmark")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .keyboardShortcut(.cancelAction)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 52)
                .padding(.leading, 24)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    /// 矮屏幕上整体缩小，别让招牌钻到菜单栏下面（整机 960 点高，加上下面一行提示约 1000 点）。
    static func fitScale(_ size: CGSize) -> CGFloat {
        let content: CGFloat = BoothMachine.isAvailable ? 1000 : 780
        return min(1, max(0.6, (size.height - 70) / content))
    }
}

/// 布帘里面：灯泡、招牌，然后是「选相框」或取景框（截图工作室也用它）。
struct BoothInterior: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    private var choosing: Bool { booth.phase == .choosingFrame || booth.phase == .closingCurtain }

    var body: some View {
        if BoothMachine.isAvailable {
            VStack(spacing: 14) {
                BoothMachine(booth: booth, previews: booth.previews, session: session, camera: camera)
                Text(choosing ? String(localized: "← → 换相框 · ↑ ↓ 四格条 / 四宫格 · Return 开始 · Esc 离开") : String(localized: "Esc 取消 · 一次一条，不能重拍"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            drawn
        }
    }

    /// 渲染图缺失时的退路：画出来的招牌 + 面板 + 取景框。
    private var drawn: some View {
        VStack(spacing: 18) {
            BoothSign()

            ZStack {
                if choosing {
                    BoothFrameChooser(booth: booth, previews: booth.previews)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))
                } else {
                    CameraWindow(booth: booth, session: session, camera: camera)
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            }

            if choosing {
                Text("← → 换相框 · ↑ ↓ 四格条 / 四宫格 · Return 开始 · Esc 离开")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 14) {
                    ForEach(0..<booth.totalShots, id: \.self) { index in
                        Circle()
                            .fill(index < booth.shot || (index == booth.shot && booth.phase == .pause) ? Palette.terracotta : Color.white.opacity(0.35))
                            .frame(width: 12, height: 12)
                    }
                }
                Text("Esc 取消 · 一次一条，不能重拍")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

/// 招牌：Blender 渲染的镀铬框灯泡牌（`BoothMarquee`），中间的搪瓷牌上印「大头贴机」；缺图时用画的灯泡 + 胶囊牌。
private struct BoothSign: View {
    @State private var flicker = false

    var body: some View {
        if BundledImage.has("BoothMarquee") {
            ZStack {
                Image("BoothMarquee")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 400, height: 125)
                    .brightness(flicker ? 0.015 : 0)
                Text("大头贴机")
                    .font(RetroFont.serif(30, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(Palette.charcoal)
                    .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
            }
            .shadow(color: Color(hex: 0xFFC56A, opacity: 0.45), radius: 18)
            .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { flicker = true }
            }
        } else {
            VStack(spacing: 18) {
                MarqueeBulbs()
                Text("大头贴机")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.charcoal)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.ivory))
                    .overlay(Capsule().stroke(Palette.terracotta, lineWidth: 3))
            }
        }
    }
}

/// 招牌上方的一排暖光灯泡（渲染图缺失时的退路）。
private struct MarqueeBulbs: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<9, id: \.self) { _ in
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.93, blue: 0.75), Color(red: 1, green: 0.7, blue: 0.35)], center: .center, startRadius: 1, endRadius: 9))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.orange.opacity(0.8), radius: 6)
            }
        }
    }
}

/// 取景框：按所选版式的格子比例（四格条横 4:3，四宫格竖 3:4）。
private struct CameraWindow: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    private var size: CGSize {
        booth.boothFormat == .boothGrid ? CGSize(width: 372, height: 496) : CGSize(width: 600, height: 450)
    }

    var body: some View {
        ZStack {
            CameraPreview(session: session, mirrored: true, isRunning: camera.isRunning)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [Palette.ivoryLight, Palette.ivoryShade], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
        )
    }
}

struct PhaseOverlay: View {
    let phase: PhotoBoothController.Phase

    var body: some View {
        switch phase {
        case .lookHere:
            Text("请看镜头！")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 10)
        case .countdown(let n):
            Text("\(n)")
                .font(.system(size: 150, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 14)
                .contentTransition(.numericText())
        default:
            EmptyView()
        }
    }
}
