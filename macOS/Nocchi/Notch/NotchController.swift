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
    /// 暂存架：展开显示暂存的相片。
    case shelf
    /// 有东西被拖到刘海上方：相片 → 暂存；图片文件 → 冲印。
    case dropTarget
    /// 胶卷柜：一排排胶卷罐，挑一卷装上。
    case films
}

/// 拖到刘海上的是什么。
enum NotchDropKind: Equatable {
    case photo
    case files
}

/// 提示的样子：和灵动岛一样，短的只在刘海两侧伸出一小截，长的向下长出一条。
enum NotchToastStyle: Equatable {
    /// 紧凑：高度与刘海相同，左翼图标、右翼文字。
    case compact
    /// 横幅：岛向下长出一条，图标和文字在下面一行。
    case banner
}

/// 自拍取景器的版式。岛的高度由这些常量推出来，内容永远不会被裁掉。
enum SelfieLayout {
    /// 镜头外圈直径。
    static let lens: CGFloat = 236
    /// 取景器（镜头里的实时画面）直径。
    static let viewfinder: CGFloat = 196
    /// 刘海那一行下面到镜头的间距。
    static let topGap: CGFloat = 10
    /// 镜头到按钮行的间距。
    static let rowGap: CGFloat = 16
    /// 按钮行高度（快门键直径）。
    static let row: CGFloat = 58
    /// 底边距。
    static let bottomInset: CGFloat = 20
    /// 岛主体的最小宽度。
    static let minWidth: CGFloat = 440

    /// 刘海那一行以下的内容高度。
    static var contentHeight: CGFloat { topGap + lens + rowGap + row + bottomInset }
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
    @Published private(set) var dropKind: NotchDropKind = .photo
    @Published private(set) var toastStyle: NotchToastStyle = .compact
    /// 提示右翼前面带一颗绿色小圆点（「营业中」）。
    @Published private(set) var toastLive = false
    private var toastTextWidth: CGFloat = 0

    /// 面板固定尺寸，足够容纳最大的状态（自拍、胶卷柜）。
    let panelSize = CGSize(width: 860, height: 460)

    /// 紧凑提示单侧翼的最小 / 最大宽度。
    private static let wingRange: ClosedRange<CGFloat> = 44...96

    private var panel: NotchPanel?
    private var screen: NSScreen?
    private var monitors: [Any] = []
    private var keyMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var dragPasteboardCount = NSPasteboard(name: .drag).changeCount
    private var dropResetWork: DispatchWorkItem?

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
        // 从 Finder 等处拖文件过来：拖动中靠近刘海就变成「冲印」投放区。
        if let fileDrag = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.externalDrag(event) }
        }) {
            monitors.append(fileDrag)
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
            let extra: CGFloat = NotchShelf.shared.isEmpty ? 0 : 92
            return CGSize(width: max(w0 + 420, 610) + extra, height: h0 + 110)
        case .films:
            return CGSize(width: max(w0 + 470, 720), height: h0 + 176)
        case .selfie:
            return CGSize(width: max(w0 + 190, SelfieLayout.minWidth), height: h0 + SelfieLayout.contentHeight)
        case .ejecting:
            return CGSize(width: max(w0, slotWidth + 30), height: h0 + 12)
        case .toast:
            switch toastStyle {
            case .compact:
                let extra: CGFloat = toastLive ? 14 : 0
                let wing = min(max(toastTextWidth + 22 + extra, Self.wingRange.lowerBound), Self.wingRange.upperBound)
                return CGSize(width: w0 + 2 * wing, height: h0)
            case .banner:
                let width = max(w0 + 180, 340, min(toastTextWidth + 84, 560))
                return CGSize(width: width, height: h0 + 38)
            }
        case .shelf:
            return CGSize(width: max(w0 + 360, 620), height: h0 + 196)
        case .dropTarget:
            return CGSize(width: max(w0 + 200, 420), height: h0 + 86)
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
        case .hover, .shelf, .films:
            if islandScreenRect(for: mode).insetBy(dx: -18, dy: -18).contains(location) {
                collapseWork?.cancel()
            } else {
                scheduleCollapse()
            }
        case .selfie, .ejecting, .dropTarget:
            break
        }
        updateMousePassThrough(location)
    }

    private func updateMousePassThrough(_ location: NSPoint) {
        let interactive: Bool
        switch mode {
        case .hover, .selfie, .shelf, .films:
            interactive = islandScreenRect(for: mode).contains(location)
        case .dropTarget:
            interactive = dropKind == .files
        default:
            interactive = false
        }
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
                if self.mode == .hover || self.mode == .shelf || self.mode == .films { self.collapse() }
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
        if mode == .hover || mode == .toast || mode == .shelf || mode == .films {
            setMode(.idle)
        }
    }

    // MARK: - Shelf & drops

    func openShelf() {
        guard mode == .hover || mode == .idle || mode == .toast else { return }
        setMode(.shelf)
        Sound.play(.cardSlide)
    }

    func closeShelf() {
        if mode == .shelf { setMode(.idle) }
    }

    // MARK: - Screenshot studio

    /// 截图工作室用：直接切到某个样子（悬停面板、胶卷柜），不等鼠标。
    func showcase(_ newMode: NotchMode) {
        setMode(newMode)
    }

    /// 截图工作室用：刘海面板窗口。
    var panelWindow: NSWindow? { panel }

    // MARK: - Film cabinet

    /// 打开胶卷柜（从悬停面板点胶卷罐）。
    func openFilms() {
        guard mode == .hover || mode == .idle || mode == .toast else { return }
        setMode(.films)
        Sound.play(.cardSlide)
    }

    /// 回到悬停面板。
    func closeFilms() {
        if mode == .films { setMode(.hover) }
    }

    /// 在胶卷柜里装上一卷。
    func loadFilm(_ stock: FilmStock) {
        let model = AppModel.shared
        let changed = model.stockID != stock.id
        model.stockID = stock.id
        Sound.play(.gearClick)
        Haptics.align()
        collapse()
        if changed {
            showToast("装上了 \(stock.name)", symbol: "film")
        }
    }

    /// 投放区（屏幕坐标）：刘海附近一块宽松的区域。
    private var dropZone: CGRect {
        metrics.rect.insetBy(dx: -110, dy: -70)
    }

    /// 桌上的相片被拖着移动。
    func photoDragMoved(to location: NSPoint) {
        let inside = dropZone.contains(location)
        if inside, mode == .idle || mode == .hover || mode == .toast || mode == .shelf || mode == .films {
            dropKind = .photo
            setMode(.dropTarget)
            Haptics.align()
        } else if !inside, mode == .dropTarget, dropKind == .photo {
            setMode(.idle)
        }
    }

    /// 相片在刘海上方松手：返回 true 表示被暂存架接住。
    func finishPhotoDrag(at location: NSPoint) -> Bool {
        guard mode == .dropTarget, dropKind == .photo else { return false }
        setMode(.idle)
        return dropZone.contains(location)
    }

    private func externalDrag(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDragged:
            let count = NSPasteboard(name: .drag).changeCount
            let dragging = count != dragPasteboardCount
            guard dragging else { return }
            if dropZone.contains(location) {
                if mode == .idle || mode == .hover || mode == .toast || mode == .shelf || mode == .films {
                    dropKind = .files
                    setMode(.dropTarget)
                    Haptics.align()
                }
            } else if mode == .dropTarget, dropKind == .files {
                setMode(.idle)
            }
        case .leftMouseUp:
            dragPasteboardCount = NSPasteboard(name: .drag).changeCount
            if mode == .dropTarget, dropKind == .files {
                // 给 onDrop 一点时间接收文件，再收起。
                dropResetWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    MainActor.assumeIsolated {
                        if self?.mode == .dropTarget { self?.setMode(.idle) }
                    }
                }
                dropResetWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            }
        default:
            break
        }
    }

    /// 从 Finder 拖来的图片文件：每张都冲印成拍立得。
    func acceptDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: NSURL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                guard let url = object as? URL ?? (object as? NSURL).map({ $0 as URL }) else { return }
                Task { @MainActor in
                    Darkroom.shared.developDroppedFile(at: url)
                }
            }
        }
        setMode(.idle)
        return accepted
    }

    func showToast(_ text: String, symbol: String, duration: TimeInterval = 2.4, live: Bool = false) {
        guard mode == .idle || mode == .toast else { return }
        let width = Self.measureToast(text)
        toastText = text
        toastSymbol = symbol
        toastLive = live
        toastTextWidth = width
        let extra: CGFloat = live ? 14 : 0
        toastStyle = width + 22 + extra <= Self.wingRange.upperBound ? .compact : .banner
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

    /// 提示文字的宽度（与 `ToastBand` 里的字体一致：12pt 圆体半粗）。
    static func measureToast(_ text: String) -> CGFloat {
        let base = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12) } ?? base
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }

    /// 启动问候：刘海像灵动岛一样轻轻醒一下（「营业中」），第一次启动再教一下怎么用。
    func greet(firstLaunch: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.showToast("营业中", symbol: AppModel.shared.currentBody.symbolName, duration: 1.6, live: true)
                guard firstLaunch else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { [weak self] in
                    MainActor.assumeIsolated {
                        self?.showToast("把鼠标移到刘海上试试", symbol: "hand.point.up.left.fill", duration: 4)
                    }
                }
            }
        }
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

    private var isPreparingCamera = false

    func enterSelfie() {
        guard mode != .selfie, mode != .ejecting, !isPreparingCamera, !PhotoBoothController.shared.isActive else { return }
        isPreparingCamera = true
        collapse()
        Task {
            defer { self.isPreparingCamera = false }
            // 先拿到摄像头权限（系统弹窗不会被任何 Nocchi 界面挡住），再展开取景器。
            guard await CameraAccess.ensure() else {
                CameraAccess.presentDeniedAlert()
                return
            }
            self.setMode(.selfie)
            Sound.play(.powerOn)
            self.panel?.makeKey()
            self.installKeyMonitor()
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
