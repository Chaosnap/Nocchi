import Foundation
import SwiftUI

/// 卡片的飞行编排：从自己字母那一格里斜着抽出来 → 离开盒口时转正 → 落到右边那一叠上；放回时反过来。
///
/// 模型（`CardBoxModel.pulled`）只说「哪些卡在桌上、谁在上面」；这里负责让每张卡按阶段走完动画，
/// 放回去的卡在沉回盒子之前还要继续画着。
@MainActor
final class CardFlights: ObservableObject {
    enum Phase: Equatable {
        /// 立在自己那一格里（和分隔卡同一个斜面），整张在格口线以下、看不见。
        case inBox
        /// 沿分隔卡方向往上抽，刚好整张露出格口。
        case rising
        /// 抽出来、悬在盒子上方，正在转向镜头。
        case lifted
        /// 落在右边那一叠上。
        case spread

        /// 这一阶段要不要用格口线遮住下半截。
        var masked: Bool { self == .inBox || self == .rising }
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
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                order = newOrder
            }
        }
    }

    /// 新抽出来的卡：无动画地立进格子，下一帧沿分隔卡往上抽，悬在盒口上方转正，再落到右边。
    private func launch(_ id: UUID) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            phases[id] = .inBox
        }
        tasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000)
            guard let self, !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.34)) {
                self.phases[id] = .rising
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                self.phases[id] = .lifted
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) {
                self.phases[id] = .spread
            }
            self.tasks[id] = nil
        }
    }

    /// 放回的卡：飞回盒口上方 → 对准自己那一格、斜过来 → 沉下去 → 不再画。
    private func land(_ id: UUID) {
        leaving.insert(id)
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                self.phases[id] = .lifted
            }
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.26)) {
                self.phases[id] = .rising
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.22)) {
                self.phases[id] = .inBox
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            self.leaving.remove(id)
            self.phases[id] = nil
            self.order.removeAll { $0 == id }
            self.tasks[id] = nil
            if self.latest.contains(id) {
                self.sync(with: self.latest)
            }
        }
    }
}
