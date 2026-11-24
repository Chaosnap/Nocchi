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

    /// 出片时挂在出片口上的摆（度、度 / 秒）。
    private struct Swing {
        var angle: Double = 0
        var velocity: Double = 0

        /// 单摆一步：伸出来越长摆得越慢（ω² ∝ 1 / L），带空气阻尼。
        mutating func step(_ dt: TimeInterval, length: CGFloat, damping: Double = 2.4) {
            let omega2 = 9000 / Double(max(length, 12))
            velocity += (-omega2 * angle - damping * velocity) * dt
            angle = min(max(angle + velocity * dt, -2.6), 2.6)
        }
    }

    /// 从刘海出片：窗口顶边对齐出片口下沿，滚轮一步一步把相纸推出来（每一步先快后慢、末尾带一点齿轮间隙的回弹），
    /// 推出来的那一截挂在出片口上像单摆一样轻轻摆、每推一下给它一点冲量；光泽随纸移动扫过去。
    func presentEjecting(windowOrigin: NSPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        isEjecting = true
        model.masking = true
        model.ejectProgress = 0
        model.ejectSway = 0
        model.ejectJitter = 0
        model.tilt = 0
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.ignoresMouseEvents = true
        panel.setFrameOrigin(windowOrigin)
        panel.orderFrontRegardless()
        Sound.play(.motor, duration: duration)

        let steps = 8
        let length = model.paperSize.height
        var elapsed: TimeInterval = 0
        var lastStep = -1
        var swing = Swing()
        var rng = SeededRandom(seed: record.seed ^ 0xE1EC7)
        let ticker = FrameTicker { [weak self] dt in
            guard let self else { return false }
            elapsed += dt
            let t = min(1, elapsed / duration)
            let raw = t * Double(steps)
            let step = min(Int(raw), steps - 1)
            let within = min(1, (raw - Double(step)) * 1.25)
            // 每一步：滚轮先快后慢地推出去，推到头往回让一点点（齿轮间隙）。
            let push = 1 - pow(1 - within, 3)
            let backlash = sin(within * .pi) * 0.05
            let eased = (Double(step) + push - backlash) / Double(steps)
            let progress = t >= 1 ? 1 : min(1, max(0, eased))
            self.model.ejectProgress = CGFloat(progress)
            if step != lastStep {
                lastStep = step
                Haptics.tick()
                swing.velocity += rng.range(-1, 1) * 9 + (step % 2 == 0 ? 3.5 : -3.5)
                self.model.ejectJitter = CGFloat(rng.range(-0.45, 0.45))
            }
            swing.step(dt, length: CGFloat(progress) * length)
            self.model.ejectSway = swing.angle
            self.model.sheen = CGPoint(x: 0.22 + 0.5 * progress, y: 0.08 + 0.22 * progress)
            if t >= 1 {
                self.finishEjecting(swing: swing, completion)
                return false
            }
            return true
        }
        ejectTicker = ticker
        ticker.start()
    }

    /// 吐完：滚轮再夹一小会儿（余摆），松开 → 纸在重力下落到桌上（一点横向漂移、像落叶那样转到随手的角度），
    /// 落地时轻轻一弹、阴影收紧、「嗒」的一声。
    private func finishEjecting(swing: Swing, _ completion: @escaping () -> Void) {
        ejectTicker = nil
        model.ejectProgress = 1
        model.ejectJitter = 0
        model.developingStarted = true
        panel.level = .floating

        let start = panel.frame.origin
        let restTilt = record.desk?.rotation ?? 0
        let length = model.paperSize.height
        var rng = SeededRandom(seed: record.seed ^ 0xFA11)
        let drop = CGFloat(rng.range(50, 66))
        let drift = CGFloat(rng.range(-12, 12))
        let hold: TimeInterval = 0.14
        let gravity: CGFloat = 2600
        var hanging = swing
        var time: TimeInterval = 0
        var released = false
        var landed = false
        var bounced = false
        var y: CGFloat = 0
        var vy: CGFloat = 0
        var angle = 0.0
        var spin = 0.0
        let ticker = FrameTicker { [weak self] dt in
            guard let self else { return false }
            time += dt
            if !released {
                // 还夹在滚轮里：只剩余摆。
                hanging.step(dt, length: length, damping: 3)
                self.model.ejectSway = hanging.angle
                guard time >= hold else { return true }
                released = true
                // 摆动换成绕纸中心的转动，接着落下；出片口合上。
                angle = hanging.angle
                spin = hanging.velocity * 0.6 + Double(drift) * 0.4
                self.model.ejectSway = 0
                self.model.tilt = angle
                self.model.masking = false
                self.model.lifted = true
                self.isEjecting = false
                completion()
                return true
            }
            if !landed {
                vy += gravity * CGFloat(dt)
                vy *= 1 - 0.8 * CGFloat(dt)
                y += vy * CGFloat(dt)
                if y >= drop {
                    y = drop
                    if !bounced, vy > 240 {
                        bounced = true
                        vy = -vy * 0.14
                        Haptics.tick()
                        Sound.play(.paperLand)
                        self.model.lifted = false
                    } else {
                        vy = 0
                        landed = true
                    }
                }
            }
            // 像落叶那样转到随手的角度：欠阻尼的弹簧（落地后摩擦更大，很快停住）。
            let omega2 = landed ? 140.0 : 70.0
            let damping = landed ? 14.0 : 3.6
            spin += (-omega2 * (angle - restTilt) - damping * spin) * dt
            angle += spin * dt
            self.model.tilt = angle
            let progress = min(1, y / max(drop, 1))
            self.panel.setFrameOrigin(NSPoint(x: start.x + drift * progress, y: start.y - y))
            if landed, abs(angle - restTilt) < 0.05, abs(spin) < 0.6 {
                self.model.tilt = restTilt
                self.panel.ignoresMouseEvents = false
                self.updatePlacement()
                self.ejectTicker = nil
                return false
            }
            return true
        }
        ejectTicker = ticker
        ticker.start()
    }

    /// 恢复到桌面上（已显影或接着显影）。
    func presentResting(at origin: NSPoint) {
        model.developingStarted = true
        model.tilt = record.desk?.rotation ?? 0
        panel.setFrameOrigin(origin)
        applyLayer()
        panel.orderFrontRegardless()
        updateSheen()
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
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: animated ? 820_000_000 : 0)
            withAnimation(.easeInOut(duration: 0.6)) { self?.updateSheen() }
        }
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
        updateSheen()
        NotchController.shared.photoDragMoved(to: point)
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
        if NotchController.shared.finishPhotoDrag(at: NSEvent.mouseLocation) {
            stashIntoNotch()
            return
        }
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

    /// 光面高光跟着相片在屏幕上的位置走（像一盏固定在屏幕左上方的灯）。
    func updateSheen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let frame = screen.frame
        let x = (panel.frame.midX - frame.minX) / max(frame.width, 1)
        let y = 1 - (panel.frame.midY - frame.minY) / max(frame.height, 1)
        model.sheen = CGPoint(x: 1 - min(max(x, 0), 1), y: min(max(y, 0), 1) * 0.6)
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

    /// 收进刘海暂存架：相片缩小着滑进刘海。
    func stashIntoNotch() {
        let notch = NotchController.shared.metrics.rect
        let target = NSRect(x: notch.midX - 12, y: notch.minY - 4, width: 24, height: 24)
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().setFrame(target, display: true)
            self.panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.model.record.desk = nil
                self.saveNow()
                NotchShelf.shared.add(self.model.record)
                Sound.play(.cardSlide)
                Haptics.tick()
                NotchController.shared.showToast("放进刘海暂存了（\(NotchShelf.shared.items.count) 张）", symbol: "tray.full.fill")
                self.close()
            }
        })
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
                let spec = PrintSpec(record: record, stockPaper: paper, images: images, widthPixels: record.format.printPixelWidth)
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
        item("装饰…", #selector(decorate))
        menu.addItem(.separator())
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

    /// 打开装饰台（右键「装饰…」或双击）。
    @objc func decorate() {
        DecorateDesk.shared.open(model.record)
    }

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
                controller.decorate()
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
