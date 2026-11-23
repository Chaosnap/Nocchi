import AppKit
import AVFoundation
import NocchiKit
import SwiftUI

/// 可以成为 key window 的无边框窗口（接收 Esc）。
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 大头贴机：先拿到摄像头权限 → 拉帘 → 请看镜头 → 3、2、1 → 白屏闪光 × 4 → 拉开帘子 → 四格条从刘海出片。
///
/// 任何情况下都能离开：权限在显示布帘之前就问好；布帘窗口在菜单栏之下（菜单栏里的「退出」始终可点）；
/// 有「离开」按钮、Esc、⌘Q；拍照有超时；整个流程有看门狗。
@MainActor
final class PhotoBoothController: ObservableObject {
    static let shared = PhotoBoothController()

    enum Phase: Equatable {
        case idle
        case closingCurtain
        case lookHere
        case countdown(Int)
        case flash
        case pause
        case openingCurtain
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var shot = 0
    @Published private(set) var curtainDown: CGFloat = 0
    let totalShots = 4
    let curtain = CurtainScene()

    private var window: KeyableWindow?
    private var task: Task<Void, Never>?
    private var keyMonitor: Any?
    private var session = 0
    private var isPreparing = false

    var isActive: Bool { phase != .idle || isPreparing }

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
            self.phase = .closingCurtain
            self.shot = 0
            self.showWindow(on: screen)
            self.task = Task { await self.run(session: current) }
            // 2. 看门狗：60 秒还没结束就强制收起。
            Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if self.session == current, self.phase != .idle {
                    self.cancel()
                    NotchController.shared.showToast("大头贴机超时了，已经收起", symbol: "exclamationmark.triangle.fill")
                }
            }
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

    private func run(session current: Int) async {
        let camera = CameraService.shared
        var frames: [CGImage] = []
        do {
            Sound.play(.coin)
            try await pause(0.4)
            Sound.play(.curtain)
            curtain.drop(duration: 0.9)
            withAnimation(.easeInOut(duration: 0.9)) { curtainDown = 1 }
            try await camera.start()
            try await pause(0.9)
            try checkSession(current)
            phase = .lookHere
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
            NotchController.shared.showToast("大头贴没拍到，再来一次", symbol: "exclamationmark.triangle.fill")
            return
        }
        // 少拍了的格子用最后一张补上（不能重拍，就是这么任性）。
        while frames.count < totalShots, let last = frames.last {
            frames.append(last)
        }
        await Darkroom.shared.develop(frames, source: .booth, body: .photoBooth, mirror: true)
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
        let host = NSHostingView(rootView: BoothCurtainView(booth: self, session: CameraService.shared.session, camera: CameraService.shared))
        host.sizingOptions = []
        window.contentView = host
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 {
                    self?.cancel()
                    return nil
                }
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "q" {
                    self?.cancel()
                    NSApp.terminate(nil)
                    return nil
                }
                return event
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
    }
}

/// 布帘（3D）、取景框、倒数、闪光，以及始终可见的「离开」按钮。
struct BoothCurtainView: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.62 * booth.curtainDown)

                BoothInterior(booth: booth, session: session, camera: camera)
                    .opacity(Double(booth.curtainDown))
                    .scaleEffect(0.96 + 0.04 * booth.curtainDown)

                CurtainSceneView(curtain: booth.curtain)
                    .allowsHitTesting(false)

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
}

private struct BoothInterior: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(0..<9, id: \.self) { _ in
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 1, green: 0.93, blue: 0.75), Color(red: 1, green: 0.7, blue: 0.35)], center: .center, startRadius: 1, endRadius: 9))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.orange.opacity(0.8), radius: 6)
                }
            }
            Text("大头贴机")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.charcoal)
                .padding(.horizontal, 26)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.ivory))
                .overlay(Capsule().stroke(Palette.terracotta, lineWidth: 3))

            ZStack {
                CameraPreview(session: session, mirrored: true, isRunning: camera.isRunning)
                    .frame(width: 600, height: 450)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                PhaseOverlay(phase: booth.phase)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.ivoryLight, Palette.ivoryShade], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
            )

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

private struct PhaseOverlay: View {
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
