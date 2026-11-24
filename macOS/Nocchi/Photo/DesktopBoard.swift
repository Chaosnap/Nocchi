import AppKit
import NocchiKit

/// 管理桌面上所有照片：出片、照片堆、显影计时、恢复、收起。
@MainActor
final class DesktopBoard {
    static let shared = DesktopBoard()

    private(set) var controllers: [UUID: PhotoWindowController] = [:]
    /// 照片堆，新的在前。
    private var pile: [UUID] = []
    private var ticker: FrameTicker?

    private init() {}

    // MARK: - Eject

    func eject(record: PhotoRecord, negatives: [CGImage], stock: FilmStock) {
        let model = PhotoViewModel(record: record, negatives: negatives, paper: stock.paper, developed: false, developSeconds: AppModel.shared.developSeconds)
        let controller = makeController(model)
        let notch = NotchController.shared
        notch.beginEjecting(slotWidth: model.paperWidth)

        let size = model.windowSize
        let pad = PhotoViewModel.padding
        let origin = NSPoint(x: notch.metrics.rect.midX - size.width / 2, y: notch.slotBottomY + pad - size.height)
        let duration = record.body.ejectDuration

        Task { @MainActor in
            // 先让出片口张开，再开始吐纸。
            try? await Task.sleep(nanoseconds: 280_000_000)
            controller.presentEjecting(windowOrigin: origin, duration: duration) { [weak self, weak controller] in
                notch.endEjecting()
                self?.startTicker()
                if let controller { self?.scheduleJoinPile(controller) }
            }
        }
    }

    /// 照片停稳后，如果没人拿起它，就慢慢飘进右上角的照片堆。
    private func scheduleJoinPile(_ controller: PhotoWindowController) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard controller.inPile, !controller.isDragging, controllers[controller.model.id] != nil else { return }
            pile.removeAll { $0 == controller.model.id }
            pile.insert(controller.model.id, at: 0)
            layoutPile(animated: true)
        }
    }

    /// 重新排列照片堆：最新的在最上面，旧的被挤到左下。
    func layoutPile(animated: Bool) {
        pile = pile.filter { controllers[$0]?.inPile == true }
        guard let screen = NotchController.shared.targetScreen else { return }
        let visible = screen.visibleFrame
        for (index, id) in pile.enumerated().reversed() {
            guard let controller = controllers[id] else { continue }
            let slot = PileLayout.slot(index: index, seed: controller.model.record.seed)
            let paper = controller.model.paperSize
            let size = controller.model.windowSize
            let center = NSPoint(
                x: visible.maxX - paper.width / 2 - 40 + slot.offset.width,
                y: visible.maxY - paper.height / 2 - 30 - slot.offset.height
            )
            let origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
            controller.move(to: origin, tilt: slot.rotation, animated: animated)
            if controller.panel.level == .floating {
                controller.panel.orderFrontRegardless()
            }
        }
    }

    // MARK: - Restore & collect

    /// 启动时把上次留在桌面上的照片放回去。
    func restore() {
        let library = Services.library
        let records = library.loadAll().filter { $0.desk != nil }
        for record in records.reversed() {
            let negatives = library.loadNegatives(of: record)
            guard !negatives.isEmpty, let desk = record.desk else { continue }
            let stock = AppModel.shared.stock(id: record.stockID)
            let model = PhotoViewModel(record: record, negatives: negatives, paper: stock.paper, developed: record.developed, developSeconds: AppModel.shared.developSeconds)
            let controller = makeController(model)
            controller.inPile = false
            var origin = NSPoint(x: desk.x, y: desk.y)
            let frame = NSRect(origin: origin, size: model.windowSize)
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }), let screen = NotchController.shared.targetScreen {
                origin = NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2)
            }
            controller.presentResting(at: origin)
            if !record.blotches.isEmpty {
                controller.refreshBlotches()
            }
        }
        if controllers.values.contains(where: { !$0.model.isDeveloped }) {
            startTicker()
        }
    }

    /// 从相册放回桌面：作为最新的一张进照片堆。
    func put(_ record: PhotoRecord) {
        if let existing = controllers[record.id] {
            existing.panel.orderFrontRegardless()
            return
        }
        let library = Services.library
        let negatives = library.loadNegatives(of: record)
        guard !negatives.isEmpty else { return }
        var record = record
        record.desk = DeskPlacement(x: 0, y: 0, rotation: PhotoRecord.randomTilt(seed: record.seed), layer: AppModel.shared.defaultLayer)
        let stock = AppModel.shared.stock(id: record.stockID)
        let model = PhotoViewModel(record: record, negatives: negatives, paper: stock.paper, developed: true, developSeconds: AppModel.shared.developSeconds)
        let controller = makeController(model)
        if let screen = NotchController.shared.targetScreen {
            let size = model.windowSize
            controller.presentResting(at: NSPoint(x: screen.visibleFrame.maxX - size.width, y: screen.visibleFrame.maxY - size.height))
        }
        if !record.blotches.isEmpty {
            controller.refreshBlotches()
        }
        pile.insert(record.id, at: 0)
        layoutPile(animated: true)
        controller.saveNow()
    }

    /// 装饰台保存后：桌面上的这张照片换成新的记录（模板、贴纸、笔画、题字都会重画），位置不变。
    func refresh(_ record: PhotoRecord) {
        guard let controller = controllers[record.id] else { return }
        var updated = record
        updated.desk = controller.model.record.desk
        controller.model.record = updated
    }

    func collectAll() {
        for controller in Array(controllers.values) {
            controller.collect()
        }
    }

    func persistAll() {
        for controller in controllers.values {
            controller.saveNow()
        }
    }

    // MARK: - Internals

    private func makeController(_ model: PhotoViewModel) -> PhotoWindowController {
        let controller = PhotoWindowController(model: model)
        controller.onRemove = { [weak self] controller in
            self?.controllers[controller.model.id] = nil
            self?.pile.removeAll { $0 == controller.model.id }
        }
        controller.onUserMoved = { [weak self] controller in
            guard let self else { return }
            if self.pile.contains(controller.model.id) {
                self.pile.removeAll { $0 == controller.model.id }
                self.layoutPile(animated: true)
            }
        }
        controller.onDeveloped = { [weak self] controller in
            self?.developmentFinished(controller)
        }
        controllers[model.id] = controller
        return controller
    }

    /// 设置里开了「显影完成后自动打开装饰台」时打开它。等「叮」一声、成片合成好再开；
    /// 用户还拿着相片在甩的时候不抢焦点；装饰台已经开着（正在装饰另一张）时不打断。
    private func developmentFinished(_ controller: PhotoWindowController) {
        guard AppModel.shared.autoOpenDecorate, !DecorateDesk.shared.isOpen else { return }
        let id = controller.model.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            var waited = 0
            while self?.controllers[id]?.isDragging == true, waited < 150 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                waited += 1
            }
            guard let self, let controller = self.controllers[id],
                  AppModel.shared.autoOpenDecorate, !DecorateDesk.shared.isOpen,
                  !PhotoBoothController.shared.isActive else { return }
            DecorateDesk.shared.open(controller.model.record)
        }
    }

    private func startTicker() {
        if ticker?.isRunning == true { return }
        let ticker = FrameTicker { [weak self] dt in
            guard let self else { return false }
            var anyDeveloping = false
            for controller in self.controllers.values {
                if controller.tick(dt) {
                    anyDeveloping = true
                }
            }
            return anyDeveloping
        }
        self.ticker = ticker
        ticker.start()
    }
}
