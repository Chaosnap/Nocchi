import AppKit
import NocchiKit
import SwiftUI

/// 桌面上一张照片的窗口：无边框、透明、可以拖、可以甩、可以在白边上写字。
final class PhotoPanel: NSPanel {
    init(size: CGSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PhotoWindowController: NSObject {
    let model: PhotoViewModel
    let panel: PhotoPanel
    private let interaction: PhotoInteractionView
    private var shakeDetector = ShakeDetector(config: .mouse)
    private var lastBlotchTime: TimeInterval = 0
    private var ejectTicker: FrameTicker?
    private var printTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var currentPressure: Double = 1

    /// 是否还在照片堆里（被拖到别处之后就不在了）。
    var inPile = true
    private(set) var isDragging = false
    private(set) var isEjecting = false

    /// 用户拖动后通知面板（从照片堆里移除等）。
    var onUserMoved: ((PhotoWindowController) -> Void)?
    var onRemove: ((PhotoWindowController) -> Void)?
    var onDeveloped: ((PhotoWindowController) -> Void)?

    init(model: PhotoViewModel) {
        self.model = model
        let size = model.windowSize
        panel = PhotoPanel(size: size)
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        let host = NSHostingView(rootView: InstantPhotoView(model: model))
        host.sizingOptions = []
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        interaction = PhotoInteractionView(frame: container.bounds)
        interaction.autoresizingMask = [.width, .height]
        container.addSubview(interaction)
        panel.contentView = container
        super.init()
        interaction.controller = self
    }

    var record: PhotoRecord { model.record }

    // MARK: - Presenting

    /// 从刘海出片：窗口顶边对齐出片口下沿，相纸由上往下一截一截地吐出来。
    func presentEjecting(windowOrigin: NSPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        isEjecting = true
        model.masking = true
        model.ejectProgress = 0
        model.tilt = 0
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.ignoresMouseEvents = true
        panel.setFrameOrigin(windowOrigin)
        panel.orderFrontRegardless()
        Sound.play(.motor, duration: duration)

        let steps = 8
        var elapsed: TimeInterval = 0
        var lastStep = -1
        let ticker = FrameTicker { [weak self] dt in
            guard let self else { return false }
            elapsed += dt
            let t = min(1, elapsed / duration)
            let raw = t * Double(steps)
            let step = min(Int(raw), steps - 1)
            let within = min(1, (raw - Double(step)) * 1.3)
            let eased = (Double(step) + (1 - pow(1 - within, 3))) / Double(steps)
            self.model.ejectProgress = CGFloat(t >= 1 ? 1 : min(1, eased))
            if step != lastStep {
                lastStep = step
                Haptics.tick()
            }
            if t >= 1 {
                self.finishEjecting(completion)
                return false
            }
            return true
        }
        ejectTicker = ticker
        ticker.start()
    }

    private func finishEjecting(_ completion: @escaping () -> Void) {
        ejectTicker = nil
        isEjecting = false
        model.masking = false
        model.ejectProgress = 1
        model.developingStarted = true
        panel.level = .floating
        panel.ignoresMouseEvents = false

        // 「啪」地掉下来一点，再随手歪一下。
        var frame = panel.frame
        frame.origin.y -= 46
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().setFrame(frame, display: true)
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            model.tilt = record.desk?.rotation ?? 0
        }
        updatePlacement()
        completion()
    }

    /// 恢复到桌面上（已显影或接着显影）。
    func presentResting(at origin: NSPoint) {
        model.developingStarted = true
        model.tilt = record.desk?.rotation ?? 0
        panel.setFrameOrigin(origin)
        applyLayer()
        panel.orderFrontRegardless()
    }

    /// 移动到某个位置（照片堆整理时用）。
    func move(to origin: NSPoint, tilt: Double, animated: Bool) {
        let frame = NSRect(origin: origin, size: panel.frame.size)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(frame, display: true)
            }
            withAnimation(.easeInOut(duration: 0.8)) { model.tilt = tilt }
        } else {
            panel.setFrame(frame, display: true)
            model.tilt = tilt
        }
        model.record.desk?.rotation = tilt
        model.record.desk?.x = Double(origin.x)
        model.record.desk?.y = Double(origin.y)
        scheduleSave()
    }

    func applyLayer() {
        guard !isEjecting else { return }
        if !model.isDeveloped {
            panel.level = .floating
            return
        }
        switch record.desk?.layer ?? .floating {
        case .floating:
            panel.level = .floating
        case .desktop:
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }

    // MARK: - Development

    /// 推进显影；返回是否还在显影。
    func tick(_ dt: TimeInterval) -> Bool {
        if model.tick(dt) {
            developmentFinished()
        }
        return model.developingStarted && !model.isDeveloped
    }

    private func developmentFinished() {
        Sound.play(.ding)
        model.record.developed = true
        applyLayer()
        renderPrint(delay: 0)
        onDeveloped?(self)
    }

    // MARK: - Dragging & shaking

    func beginDrag() {
        isDragging = true
        shakeDetector.reset()
        model.lifted = true
        panel.orderFrontRegardless()
    }

    func dragMoved(to point: NSPoint, time: TimeInterval) {
        guard let event = shakeDetector.add(position: point, at: time) else { return }
        guard !model.isDeveloped, model.developingStarted else { return }
        model.shake(energy: event.energy)
        if event.isViolent {
            addBlotch(time: time)
        } else if event.energy > 0.35 {
            Haptics.tick()
        }
    }

    func endDrag(moved: Bool) {
        isDragging = false
        model.lifted = false
        guard moved else { return }
        inPile = false
        snapToEdges()
        updatePlacement()
        onUserMoved?(self)
    }

    private func addBlotch(time: TimeInterval) {
        guard record.blotches.count < Blotch.maximumPerPhoto, time - lastBlotchTime > 0.7 else { return }
        lastBlotchTime = time
        model.record.blotches.append(Blotch.make(seed: record.seed, index: record.blotches.count))
        Sound.play(.splat)
        Haptics.heavy()
        refreshBlotches()
        scheduleSave()
    }

    /// 重新把色块叠到底片上。
    func refreshBlotches() {
        let negatives = model.negatives
        let record = model.record
        guard !record.blotches.isEmpty else {
            model.setDisplayImages(negatives)
            return
        }
        Task { [weak self] in
            let images: [CGImage] = await Task.detached(priority: .userInitiated) {
                negatives.enumerated().map { pair in
                    Services.processor.applyingBlotches(record.blotches(forFrame: pair.offset), to: pair.element) ?? pair.element
                }
            }.value
            self?.model.setDisplayImages(images)
        }
    }

    /// 像冰箱贴一样吸到屏幕边缘。
    private func snapToEdges() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let pad = PhotoViewModel.padding
        var frame = panel.frame
        let paper = frame.insetBy(dx: pad, dy: pad)
        let threshold: CGFloat = 44
        let margin: CGFloat = 8
        var snapped = false
        if paper.minX - visible.minX < threshold {
            frame.origin.x = visible.minX + margin - pad
            snapped = true
        } else if visible.maxX - paper.maxX < threshold {
            frame.origin.x = visible.maxX - margin - paper.width - pad
            snapped = true
        }
        if paper.minY - visible.minY < threshold {
            frame.origin.y = visible.minY + margin - pad
            snapped = true
        } else if visible.maxY - paper.maxY < threshold {
            frame.origin.y = visible.maxY - margin - paper.height - pad
            snapped = true
        }
        guard snapped else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(frame, display: true)
        }
        Sound.play(.magnet)
        Haptics.align()
    }

    private func updatePlacement() {
        let origin = panel.frame.origin
        if model.record.desk == nil {
            model.record.desk = DeskPlacement(x: 0, y: 0, rotation: model.tilt, layer: AppModel.shared.defaultLayer)
        }
        model.record.desk?.x = Double(origin.x)
        model.record.desk?.y = Double(origin.y)
        model.record.desk?.rotation = model.tilt
        scheduleSave()
    }

    // MARK: - Ink

    /// 窗口坐标（左上原点）→ 相纸坐标（考虑倾斜）。
    func paperPoint(fromView point: CGPoint, viewSize: CGSize) -> CGPoint {
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let v = CGPoint(x: point.x - center.x, y: point.y - center.y)
        let angle = CGFloat(-model.tilt * Double.pi / 180)
        let c = CGFloat(Foundation.cos(Double(angle)))
        let sn = CGFloat(Foundation.sin(Double(angle)))
        let rotated = CGPoint(x: v.x * c - v.y * sn, y: v.x * sn + v.y * c)
        return CGPoint(x: rotated.x + model.paperSize.width / 2, y: rotated.y + model.paperSize.height / 2)
    }

    func containsPaperPoint(_ point: CGPoint) -> Bool {
        CGRect(origin: .zero, size: model.paperSize).contains(point)
    }

    func isCaptionPoint(_ point: CGPoint) -> Bool {
        model.layout.scaled(model.layout.captionArea, toWidth: model.paperWidth).insetBy(dx: -6, dy: -6).contains(point)
    }

    func beginStroke(at point: CGPoint, pressure: Double) {
        currentPressure = pressure
        model.liveStroke = InkStroke(points: [inkPoint(point, pressure: pressure)], color: model.paper.ink)
    }

    func continueStroke(at point: CGPoint, pressure: Double) {
        guard var stroke = model.liveStroke else { return }
        currentPressure = pressure
        stroke.points.append(inkPoint(point, pressure: pressure))
        model.liveStroke = stroke
    }

    func updatePressure(_ pressure: Double) {
        currentPressure = pressure
    }

    func endStroke() {
        guard let stroke = model.liveStroke else { return }
        model.liveStroke = nil
        model.record.strokes.append(stroke)
        scheduleSave()
        if model.isDeveloped { renderPrint(delay: 0.8) }
    }

    private func inkPoint(_ point: CGPoint, pressure: Double) -> InkPoint {
        let w = Double(model.paperWidth)
        return InkPoint(x: Double(point.x) / w, y: Double(point.y) / w, w: InkStroke.width(pressure: pressure))
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        try? Services.library.save(model.record)
        LibraryStore.shared.upsert(model.record)
    }

    /// 合成带白边的成片写进 ~/Pictures/Nocchi。
    func renderPrint(delay: TimeInterval) {
        printTask?.cancel()
        let record = model.record
        let images = model.displayImages
        let paper = model.paper
        printTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            let relative: String? = await Task.detached(priority: .utility) {
                let spec = PrintSpec(
                    layout: record.layout,
                    paper: paper,
                    images: images,
                    frameOffsets: record.frameOffsets,
                    strokes: record.strokes,
                    caption: record.caption,
                    dateText: record.showsDate ? record.dateText : nil,
                    widthPixels: record.format.printPixelWidth
                )
                guard let image = PhotoComposer.render(spec) else { return nil }
                return try? Services.library.writePrint(image, for: record)
            }.value
            guard let self, let relative else { return }
            self.model.record.printFile = relative
            self.saveNow()
        }
    }

    // MARK: - Context menu

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector, enabled: Bool = true) {
            let menuItem = NSMenuItem(title: title, action: enabled ? action : nil, keyEquivalent: "")
            menuItem.target = self
            menu.addItem(menuItem)
        }
        let hasPrint = record.printFile != nil
        item("在 Finder 中显示", #selector(revealInFinderAction), enabled: hasPrint)
        item("用「预览」打开", #selector(openInPreview), enabled: hasPrint)
        item("拷贝", #selector(copyToPasteboard), enabled: hasPrint)
        item("共享…", #selector(share), enabled: hasPrint)
        menu.addItem(.separator())
        item(model.penMode ? "写完了" : "在白边上写字", #selector(togglePen))
        item("写一句题字…", #selector(editCaption))
        item(record.showsDate ? "不印日期" : "印上日期", #selector(toggleDate))
        if !record.strokes.isEmpty {
            item("擦掉笔迹", #selector(clearInk))
        }
        menu.addItem(.separator())
        let onDesktop = record.desk?.layer == .desktop
        item(onDesktop ? "浮到最上层" : "贴到桌面层（在窗口后面）", #selector(toggleLayer))
        item("收进相册", #selector(collect))
        menu.addItem(.separator())
        item("移到废纸篓…", #selector(trash))
        return menu
    }

    @objc func revealInFinderAction() { revealInFinder() }

    func revealInFinder() {
        guard let relative = record.printFile else {
            NotchController.shared.showToast("还在显影，等一下", symbol: "hourglass")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([Services.library.printURL(relative)])
    }

    @objc private func openInPreview() {
        guard let relative = record.printFile else { return }
        NSWorkspace.shared.open(Services.library.printURL(relative))
    }

    @objc private func copyToPasteboard() {
        guard let relative = record.printFile else { return }
        let url = Services.library.printURL(relative)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var objects: [NSPasteboardWriting] = [url as NSURL]
        if let image = NSImage(contentsOf: url) {
            objects.append(image)
        }
        pasteboard.writeObjects(objects)
        Sound.play(.gearClick)
    }

    @objc private func share() {
        guard let relative = record.printFile else { return }
        let picker = NSSharingServicePicker(items: [Services.library.printURL(relative)])
        picker.show(relativeTo: interaction.bounds.insetBy(dx: PhotoViewModel.padding, dy: PhotoViewModel.padding), of: interaction, preferredEdge: .minY)
    }

    @objc private func togglePen() {
        model.penMode.toggle()
        panel.invalidateCursorRects(for: interaction)
        if model.penMode {
            NotchController.shared.showToast("在下面的白边上写字", symbol: "pencil.tip")
        }
    }

    @objc private func editCaption() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "写一句题字"
        alert.informativeText = "会印在照片下面的白边上。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = record.caption ?? ""
        field.placeholderString = PhotoRecord.defaultCaption
        alert.accessoryView = field
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        model.record.caption = text.isEmpty ? nil : text
        scheduleSave()
        if model.isDeveloped { renderPrint(delay: 0.2) }
    }

    @objc private func toggleDate() {
        model.record.showsDate.toggle()
        scheduleSave()
        if model.isDeveloped { renderPrint(delay: 0.2) }
    }

    @objc private func clearInk() {
        model.record.strokes.removeAll()
        scheduleSave()
        if model.isDeveloped { renderPrint(delay: 0.2) }
    }

    @objc private func toggleLayer() {
        let next: DeskPlacement.Layer = record.desk?.layer == .desktop ? .floating : .desktop
        model.record.desk?.layer = next
        applyLayer()
        scheduleSave()
    }

    @objc func collect() {
        model.record.desk = nil
        saveNow()
        Sound.play(.gearClick)
        close()
    }

    @objc private func trash() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "把这张照片移到废纸篓？"
        alert.informativeText = "成片会移到废纸篓（可以从废纸篓恢复）；相册里的这张记录和底片会被删除。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let record = model.record
        if let relative = record.printFile {
            NSWorkspace.shared.recycle([Services.library.printURL(relative)], completionHandler: nil)
        }
        Services.library.removeRecord(record, deletePrint: false)
        LibraryStore.shared.remove(id: record.id)
        Sound.play(.tear)
        close()
    }

    func close() {
        printTask = nil
        ejectTicker?.stop()
        panel.orderOut(nil)
        onRemove?(self)
    }
}

/// 照片上的鼠标交互层（拖动、甩、双击、右键、写字）。
final class PhotoInteractionView: NSView {
    weak var controller: PhotoWindowController?

    private enum DragKind {
        case none
        case move
        case ink
    }

    private var dragKind: DragKind = .none
    private var startMouse: NSPoint = .zero
    private var startOrigin: NSPoint = .zero
    private var moved = false

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        MainActor.assumeIsolated {
            guard let controller else { return }
            let local = convert(event.locationInWindow, from: nil)
            let paper = controller.paperPoint(fromView: local, viewSize: bounds.size)
            guard controller.containsPaperPoint(paper) else { return }
            if event.clickCount == 2 {
                controller.revealInFinder()
                return
            }
            if controller.model.penMode, controller.isCaptionPoint(paper) {
                dragKind = .ink
                controller.beginStroke(at: paper, pressure: Double(event.pressure))
                return
            }
            dragKind = .move
            moved = false
            startMouse = NSEvent.mouseLocation
            startOrigin = window?.frame.origin ?? .zero
            controller.beginDrag()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        MainActor.assumeIsolated {
            guard let controller else { return }
            switch dragKind {
            case .ink:
                let local = convert(event.locationInWindow, from: nil)
                controller.continueStroke(at: controller.paperPoint(fromView: local, viewSize: bounds.size), pressure: Double(event.pressure))
            case .move:
                let mouse = NSEvent.mouseLocation
                if abs(mouse.x - startMouse.x) + abs(mouse.y - startMouse.y) > 2 {
                    moved = true
                }
                window?.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x, y: startOrigin.y + mouse.y - startMouse.y))
                controller.dragMoved(to: mouse, time: event.timestamp)
            case .none:
                break
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        MainActor.assumeIsolated {
            guard let controller else { return }
            switch dragKind {
            case .ink:
                controller.endStroke()
            case .move:
                controller.endDrag(moved: moved)
            case .none:
                break
            }
            dragKind = .none
        }
    }

    override func pressureChange(with event: NSEvent) {
        MainActor.assumeIsolated {
            if dragKind == .ink {
                controller?.updatePressure(Double(event.pressure))
            }
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        MainActor.assumeIsolated { controller?.makeContextMenu() }
    }

    override func resetCursorRects() {
        MainActor.assumeIsolated {
            if controller?.model.penMode == true {
                addCursorRect(bounds, cursor: .crosshair)
            }
        }
    }
}
