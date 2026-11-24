import Foundation
import SwiftUI

/// 卡片的飞行编排：从盒口升起 → 飞到右边摊开；放回时反过来。
///
/// 模型（`CardBoxModel.pulled`）只说「哪些卡在桌上、谁在上面」；这里负责让每张卡按阶段走完动画，
/// 放回去的卡在飞回盒子之前还要继续画着。
@MainActor
final class CardFlights: ObservableObject {
    enum Phase: Equatable {
        /// 在盒子里：小、低，下半截被前挡板挡住。
        case inBox
        /// 刚从盒口升起，还在前挡板后面一层。
        case rising
        /// 在盒口上方（正在飞回盒子），已经在前挡板前面一层。
        case hovering
        /// 摊在右边。
        case spread
    }

    /// 画出来的卡片，下 → 上。正在飞回盒子的卡排在最上面。
    @Published private(set) var order: [UUID] = []
    @Published private(set) var phases: [UUID: Phase] = [:]
    private(set) var leaving: Set<UUID> = []
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var latest: [UUID] = []

    func phase(of id: UUID) -> Phase {
        phases[id] ?? .inBox
    }

    func isLeaving(_ id: UUID) -> Bool {
        leaving.contains(id)
    }

    /// 和模型同步（`pulled` 下 → 上）。
    func sync(with pulled: [UUID]) {
        latest = pulled
        let target = Set(pulled)
        for id in pulled {
            if phases[id] == nil {
                launch(id)
            } else if leaving.contains(id) {
                // 飞回去的半路又被抽出来。
                leaving.remove(id)
                tasks[id]?.cancel()
                tasks[id] = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    phases[id] = .spread
                }
            }
        }
        for id in order where !target.contains(id) && !leaving.contains(id) {
            land(id)
        }
        let flying = order.filter { leaving.contains($0) }
        let newOrder = pulled + flying
        if newOrder != order {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                order = newOrder
            }
        }
    }

    /// 新抽出来的卡：先无动画地放进盒子，下一帧升起，再飞到右边。
    private func launch(_ id: UUID) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            phases[id] = .inBox
        }
        tasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000)
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.26)) {
                self.phases[id] = .rising
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.56, dampingFraction: 0.8)) {
                self.phases[id] = .spread
            }
            self.tasks[id] = nil
        }
    }

    /// 放回的卡：飞到盒口上方 → 沉进盒子 → 不再画。
    private func land(_ id: UUID) {
        leaving.insert(id)
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                self.phases[id] = .hovering
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                self.phases[id] = .inBox
            }
            try? await Task.sleep(nanoseconds: 230_000_000)
            guard !Task.isCancelled else { return }
            self.leaving.remove(id)
            self.phases[id] = nil
            self.order.removeAll { $0 == id }
            self.tasks[id] = nil
            // 飞行途中模型可能又变了。
            if self.latest.contains(id) {
                self.sync(with: self.latest)
            }
        }
    }
}
