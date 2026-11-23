import AppKit
import Combine
import NocchiKit
import SwiftUI

/// 刘海的状态。
enum NotchMode: Equatable {
    /// 平时：什么都不画（硬件刘海本身就是黑的）。
    case idle
    /// 鼠标悬停：刘海向下展开成操作面板。
    case hover
    /// 自拍：展开成镜头取景器。
    case selfie
    /// 出片：张开成一条出片口。
    case ejecting
    /// 小提示：刘海两侧显示一行字。
    case toast
}

/// 管理刘海上方的透明面板：定位、悬停展开、出片口、提示。
@MainActor
final class NotchController: ObservableObject {
    static let shared = NotchController()

    @Published private(set) var mode: NotchMode = .idle
    @Published private(set) var metrics = NotchMetrics(rect: CGRect(x: 0, y: 0, width: 196, height: 32), isHardware: false)
    @Published private(set) var slotWidth: CGFloat = 232
    @Published private(set) var toastText: String = ""
    @Published private(set) var toastSymbol: String = "camera.fill"
    /// 自拍倒数（nil 表示不在倒数）。
    @Published var countdown: Int?
    @Published private(set) var isCapturing = false

    /// 面板固定尺寸，足够容纳最大的「自拍」状态。
    let panelSize = CGSize(width: 760, height: 420)

    private var panel: NotchPanel?
    private var screen: NSScreen?
    private var monitors: [Any] = []
    private var keyMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Setup

    func install() {
        recomputeGeometry()
        let panel = NotchPanel(contentRect: panelFrame())
        let host = NSHostingView(rootView: NotchRootView(notch: self, model: AppModel.shared, camera: CameraService.shared))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel

        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved(to: NSEvent.mouseLocation) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }
    }

    /// 出片口所在的屏幕（有刘海的内建屏优先）。
    var targetScreen: NSScreen? { screen ?? NotchLocator.targetScreen() }

    private func screenParametersChanged() {
        recomputeGeometry()
        panel?.setFrame(panelFrame(), display: true)
    }

    private func recomputeGeometry() {
        guard let screen = NotchLocator.targetScreen() else { return }
        self.screen = screen
        metrics = NotchLocator.metrics(for: screen)
    }

    private func panelFrame() -> NSRect {
        let top = metrics.rect.maxY
        var x = metrics.rect.midX - panelSize.width / 2
        if let frame = screen?.frame {
            x = min(max(x, frame.minX), frame.maxX - panelSize.width)
        }
        return NSRect(x: x, y: top - panelSize.height, width: panelSize.width, height: panelSize.height)
    }

    // MARK: - Geometry shared with the SwiftUI view

    /// 岛主体（不含两侧圆角「耳朵」）的尺寸。
    func islandSize(for mode: NotchMode) -> CGSize {
        let w0 = metrics.rect.width
        let h0 = metrics.rect.height
        switch mode {
        case .idle:
            return CGSize(width: w0, height: h0)
        case .hover:
            return CGSize(width: max(w0 + 330, 560), height: h0 + 112)
        case .selfie:
            return CGSize(width: max(w0 + 190, 440), height: h0 + 300)
        case .ejecting:
            return CGSize(width: max(w0, slotWidth + 30), height: h0 + 12)
        case .toast:
            let textWidth = min(CGFloat(toastText.count) * 13 + 40, 300)
            return CGSize(width: w0 + 2 * max(textWidth, 70), height: h0)
        }
    }

    var islandSize: CGSize { islandSize(for: mode) }

    /// 岛在面板里的水平中心（面板可能因为贴边而不居中）。
    var islandCenterX: CGFloat {
        metrics.rect.midX - panelFrame().minX
    }

    /// 岛的屏幕矩形（用于判断鼠标）。
    private func islandScreenRect(for mode: NotchMode) -> CGRect {
        let size = islandSize(for: mode)
        return CGRect(x: metrics.rect.midX - size.width / 2, y: metrics.rect.maxY - size.height, width: size.width, height: size.height)
    }

    /// 出片口下沿的屏幕 y 坐标。
    var slotBottomY: CGFloat {
        metrics.rect.maxY - islandSize(for: .ejecting).height
    }

    var isIslandVisible: Bool {
        mode != .idle
    }

    // MARK: - Mouse

    private func mouseMoved(to location: NSPoint) {
        switch mode {
        case .idle, .toast:
            if metrics.hoverZone.contains(location), !PhotoBoothController.shared.isActive {
                scheduleHover()
            } else {
                hoverWork?.cancel()
            }
        case .hover:
            if islandScreenRect(for: .hover).insetBy(dx: -18, dy: -18).contains(location) {
                collapseWork?.cancel()
            } else {
                scheduleCollapse()
            }
        case .selfie, .ejecting:
            break
        }
        updateMousePassThrough(location)
    }

    private func updateMousePassThrough(_ location: NSPoint) {
        let interactive = (mode == .hover || mode == .selfie) && islandScreenRect(for: mode).contains(location)
        panel?.ignoresMouseEvents = !interactive
    }

    private func scheduleHover() {
        guard hoverWork == nil || hoverWork?.isCancelled == true else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hoverWork = nil
                if self.mode == .idle || self.mode == .toast {
                    self.setMode(.hover)
                    Haptics.tick()
                }
            }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func scheduleCollapse() {
        guard collapseWork == nil || collapseWork?.isCancelled == true else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.collapseWork = nil
                if self.mode == .hover { self.collapse() }
            }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func setMode(_ newMode: NotchMode) {
        mode = newMode
        updateMousePassThrough(NSEvent.mouseLocation)
    }

    // MARK: - Public actions

    func collapse() {
        hoverWork?.cancel()
        collapseWork?.cancel()
        if mode == .hover || mode == .toast {
            setMode(.idle)
        }
    }

    func showToast(_ text: String, symbol: String, duration: TimeInterval = 2.4) {
        guard mode == .idle || mode == .toast else { return }
        toastText = text
        toastSymbol = symbol
        setMode(.toast)
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                if self?.mode == .toast { self?.setMode(.idle) }
            }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func beginEjecting(slotWidth: CGFloat) {
        toastWork?.cancel()
        self.slotWidth = slotWidth
        setMode(.ejecting)
    }

    func endEjecting() {
        if mode == .ejecting { setMode(.idle) }
    }

    // MARK: - Selfie

    func enterSelfie() {
        guard mode != .selfie, mode != .ejecting, !PhotoBoothController.shared.isActive else { return }
        setMode(.selfie)
        Sound.play(.powerOn)
        panel?.makeKey()
        installKeyMonitor()
        Task {
            do {
                try await CameraService.shared.start()
            } catch {
                self.exitSelfie()
                self.showToast(CameraService.describe(error), symbol: "video.slash.fill", duration: 3.5)
            }
        }
    }

    func exitSelfie() {
        guard mode == .selfie else { return }
        removeKeyMonitor()
        countdown = nil
        CameraService.shared.stop()
        setMode(.idle)
    }

    func selfieShutter() {
        guard mode == .selfie, !isCapturing else { return }
        isCapturing = true
        Task {
            await Darkroom.shared.takeSelfie()
            self.isCapturing = false
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.mode == .selfie else { return event }
                switch event.keyCode {
                case 53: // esc
                    self.exitSelfie()
                    return nil
                case 49, 36, 76: // space, return, enter
                    self.selfieShutter()
                    return nil
                default:
                    return event
                }
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}

/// 找刘海。
enum NotchLocator {
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func metrics(for screen: NSScreen) -> NotchMetrics {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchMetrics.compute(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: menuBarHeight > 0 ? menuBarHeight : NSStatusBar.system.thickness
        )
    }
}

/// 刘海上方的透明面板：不抢焦点、跟随所有桌面空间、盖在菜单栏上。
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
