import AppKit
import NocchiKit
import SwiftUI

/// 胶卷柜：刘海展开成一排排胶卷罐（按即显相纸 / 彩色负片 / 夜景与电影 / 黑白 / 大头贴分组），挑一卷装上。
struct FilmCabinetPanel: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var model: AppModel
    let notchHeight: CGFloat

    @State private var hovered: FilmStock?

    private struct FilmShelfGroup: Identifiable {
        let family: FilmFamily
        let stocks: [FilmStock]
        var id: FilmFamily { family }
    }

    private var groups: [FilmShelfGroup] {
        FilmCatalog.grouped(model.stocks).map { FilmShelfGroup(family: $0.family, stocks: $0.stocks) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: notchHeight)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 22) {
                        ForEach(groups) { group in
                            section(group)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .background(WheelToHorizontalScroll())
                .onAppear {
                    proxy.scrollTo(model.stockID, anchor: .center)
                }
            }
            .frame(height: 126)
            footer
                .frame(height: 30)
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                notch.closeFilms()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("返回")
            Text("胶卷柜")
                .font(RetroFont.serif(13, weight: .semibold))
            Spacer(minLength: notch.metrics.rect.width + 24)
            Text("挑一卷装上")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .opacity(0.55)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 16)
    }

    private func section(_ group: FilmShelfGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.family.displayName)
                .font(RetroFont.typewriter(10))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
            HStack(alignment: .top, spacing: 4) {
                ForEach(group.stocks) { stock in
                    FilmCabinetTile(
                        stock: stock,
                        loaded: stock.id == model.stockID,
                        onHover: { inside in
                            if inside {
                                hovered = stock
                            } else if hovered?.id == stock.id {
                                hovered = nil
                            }
                        },
                        action: { notch.loadFilm(stock) }
                    )
                    .id(stock.id)
                }
            }
        }
    }

    private var footer: some View {
        let stock = hovered ?? model.currentStock
        return HStack(spacing: 10) {
            Text(stock.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.terracottaLight)
            Text(stock.summary)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let format = stock.recommendedFormat, !format.isBooth, format != model.instantFormat {
                Text("推荐 \(format.displayName)")
                    .font(RetroFont.typewriter(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.15), value: stock.id)
    }
}

/// 胶卷柜里的一卷：罐子（装着的那卷背后有一团暖光）、名字、ISO 与张数。
private struct FilmCabinetTile: View {
    let stock: FilmStock
    let loaded: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    if loaded {
                        RadialGradient(colors: [Palette.terracotta.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 40)
                            .frame(width: 78, height: 70)
                    }
                    FilmCanisterImage(stock: stock, size: 62)
                        .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                        .offset(y: hovering ? -4 : 0)
                }
                .frame(height: 64)
                Text(stock.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 4) {
                    if loaded {
                        Text("已装")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Palette.terracotta))
                            .foregroundStyle(.white)
                    }
                    Text("\(stock.iso) · \(stock.exposures) 张")
                        .font(RetroFont.typewriter(9))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(width: 86)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.1 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hovering = inside
            onHover(inside)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovering)
        .help(stock.summary)
    }
}

/// 鼠标滚轮上下滚动时，让横向的胶卷架左右移动（触控板横向轻扫照旧）。
///
/// 放在横向 `ScrollView` 的背景里：本地事件监视器拿到落在这块区域的滚轮事件，找到底下的 `NSScrollView`，
/// 把纵向的滚动量换成横向位移（普通滚轮按「行」计，换算成点再加一点缓动）。
struct WheelToHorizontalScroll: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ nsView: Probe, context: Context) {}

    final class Probe: NSView {
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, self.handle(event) else { return event }
                    return nil
                }
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func handle(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else { return false }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point) else { return false }
            let dy = event.scrollingDeltaY
            guard abs(dy) > abs(event.scrollingDeltaX), dy != 0, let scrollView = scrollView(in: window) else { return false }
            let clip = scrollView.contentView
            let documentWidth = scrollView.documentView?.frame.width ?? 0
            let maxX = max(0, documentWidth - clip.bounds.width)
            let step = event.hasPreciseScrollingDeltas ? dy : dy * 18
            var origin = clip.bounds.origin
            origin.x = min(max(0, origin.x - step), maxX)
            if event.hasPreciseScrollingDeltas {
                clip.setBoundsOrigin(origin)
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    context.allowsImplicitAnimation = true
                    clip.animator().setBoundsOrigin(origin)
                }
            }
            scrollView.reflectScrolledClipView(clip)
            return true
        }

        /// 窗口里覆盖这块区域、面积最小的 `NSScrollView`（SwiftUI 的横向 ScrollView 底下就是它）。
        private func scrollView(in window: NSWindow) -> NSScrollView? {
            guard let root = window.contentView else { return nil }
            let center = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
            var best: NSScrollView?
            var bestArea = CGFloat.infinity
            var stack: [NSView] = [root]
            while let view = stack.popLast() {
                if let scroll = view as? NSScrollView {
                    let frame = scroll.convert(scroll.bounds, to: nil)
                    let area = frame.width * frame.height
                    if frame.contains(center), area < bestArea {
                        best = scroll
                        bestArea = area
                    }
                }
                stack.append(contentsOf: view.subviews)
            }
            return best
        }
    }
}
