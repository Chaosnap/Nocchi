import AppKit
import AVFoundation
import NocchiKit
import SwiftUI

/// 可以成为 key window 的无边框窗口（接收 Esc）。
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 大头贴机：拉帘 → 请看镜头 → 3、2、1 → 白屏闪光 × 4 → 拉开帘子 → 四格条从刘海出片。
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

    private var window: KeyableWindow?
    private var task: Task<Void, Never>?
    private var keyMonitor: Any?

    var isActive: Bool { phase != .idle }

    private init() {}

    func start() {
        guard !isActive, NotchController.shared.mode != .selfie else { return }
        guard let screen = NotchController.shared.targetScreen else { return }
        NotchController.shared.collapse()
        phase = .closingCurtain
        shot = 0
        showWindow(on: screen)
        task = Task { await run() }
    }

    func cancel() {
        task?.cancel()
    }

    private func run() async {
        let camera = CameraService.shared
        var frames: [CGImage] = []
        do {
            Sound.play(.coin)
            try await pause(0.45)
            Sound.play(.curtain)
            withAnimation(.easeInOut(duration: 0.9)) { curtainDown = 1 }
            try await camera.start()
            try await pause(0.9)
            phase = .lookHere
            try await pause(1.3)
            for index in 0..<totalShots {
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
                if let image = try? await camera.capture() {
                    frames.append(image)
                }
                try await pause(0.16)
                phase = .pause
                try await pause(index < totalShots - 1 ? 1.5 : 0.4)
            }
            camera.stop()
            phase = .openingCurtain
            Sound.play(.curtain)
            withAnimation(.easeInOut(duration: 0.8)) { curtainDown = 0 }
            try await pause(0.85)
        } catch {
            camera.stop()
            teardown()
            if !(error is CancellationError) {
                NotchController.shared.showToast(CameraService.describe(error), symbol: "video.slash.fill", duration: 3.5)
            }
            return
        }
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

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func showWindow(on screen: NSScreen) {
        let window = KeyableWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
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

/// 布帘、取景框、倒数、闪光。
struct BoothCurtainView: View {
    @ObservedObject var booth: PhotoBoothController
    let session: AVCaptureSession
    @ObservedObject var camera: CameraService

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let gap: CGFloat = 760
            let side = max(0, (size.width - gap) / 2)
            ZStack {
                Color.black.opacity(0.62 * booth.curtainDown)

                BoothInterior(booth: booth, session: session, camera: camera)
                    .opacity(Double(booth.curtainDown))
                    .scaleEffect(0.96 + 0.04 * booth.curtainDown)

                HStack(spacing: 0) {
                    CurtainPanel(edge: .trailing)
                        .frame(width: side + 40)
                    Spacer(minLength: 0)
                    CurtainPanel(edge: .leading)
                        .frame(width: side + 40)
                }
                .frame(width: size.width, height: size.height)
                .offset(y: -size.height * (1 - booth.curtainDown))

                Color.white
                    .opacity(booth.phase == .flash ? 1 : 0)
                    .animation(.easeOut(duration: booth.phase == .flash ? 0.04 : 0.35), value: booth.phase)
            }
            .frame(width: size.width, height: size.height)
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

/// 一侧布帘：陶土橙丝绒纹理 + 内侧的阴影。
private struct CurtainPanel: View {
    let edge: HorizontalEdge

    var body: some View {
        ZStack {
            Palette.terracotta
            Image("CurtainTexture")
                .resizable(resizingMode: .tile)
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.45)],
                startPoint: edge == .trailing ? .leading : .trailing,
                endPoint: edge == .trailing ? .trailing : .leading
            )
        }
        .clipped()
    }
}
