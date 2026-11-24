import AppKit
import NocchiKit
import SwiftUI

/// 相册顶栏：左边字标、中间四种看法的切换托盘、右边搜索框、「＋」和卡片盒归档的齿轮。
///
/// 窗口是透明标题栏 + 全尺寸内容，顶栏铺在标题栏下面；红绿灯由 `TrafficLights` 挪到顶栏的垂直中线上。
struct AlbumHeader: View {
    static let height: CGFloat = 56
    /// 红绿灯占的宽度（左边距 20 + 三个按钮）。
    static let trafficLightsWidth: CGFloat = 84

    @Binding var mode: AlbumMode
    @Binding var query: String
    var searchFocused: FocusState<Bool>.Binding
    /// 卡片盒的归档方式（首字母 / 年 / 月 / 日）。
    @Binding var indexMode: CardIndexMode

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: Self.trafficLightsWidth + 8)
                Wordmark()
                Spacer(minLength: 20)
                AlbumSearchField(text: $query, focused: searchFocused)
                ImportButton()
                    .padding(.leading, 10)
                IndexModeButton(indexMode: $indexMode) {
                    // 在别的看法里换了归档方式：切到卡片盒，马上看到分隔卡换了标签。
                    if mode != .cardBox {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            mode = .cardBox
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
            }
            ModeSwitcher(mode: $mode)
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0xF7F2E8), Palette.paper], startPoint: .top, endPoint: .bottom)
                WindowDragArea()
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .zIndex(10)
    }
}

/// 字标：Didot「NOCCHI」+ 宋体「相册」。
private struct Wordmark: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("NOCCHI")
                .font(RetroFont.display(21, weight: .bold))
                .tracking(3)
            Text("相册")
                .font(RetroFont.serif(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .foregroundStyle(Palette.ink)
        .fixedSize()
        .allowsHitTesting(false)
    }
}

// MARK: - 看法切换

/// 象牙白的内凹托盘，四段；选中的一段是一块凸起的白色小卡，在段之间滑动。
private struct ModeSwitcher: View {
    @Binding var mode: AlbumMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AlbumMode.allCases) { item in
                ModeSegment(item: item, selected: item == mode, namespace: namespace) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        mode = item
                    }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.ivory.shadow(.inner(color: .black.opacity(0.2), radius: 2.2, x: 0, y: 1.2)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 0.8)
                .offset(y: 0.6)
                .mask(RoundedRectangle(cornerRadius: 12, style: .continuous).padding(-1))
        )
        .fixedSize()
    }
}

private struct ModeSegment: View {
    let item: AlbumMode
    let selected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ModeIcon(mode: item, size: 26)
                    .scaleEffect(hovering && !selected ? 1.06 : 1)
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
            }
            .padding(.leading, 7)
            .padding(.trailing, 11)
            .padding(.vertical, 4)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white, Color(hex: 0xF7F3EC)], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 0.8, y: 0.8)
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { hovering = inside }
        }
        .help(tooltip)
    }

    private var tooltip: String {
        String(localized: "\(item.title)（⌘\(String(item.key.character))）")
    }
}

/// 看法图标：Blender 渲染的小物件，缺图时用 SF Symbol。
///
/// 渲染图四周留了地方给柔和的地面阴影（`design/blender/icons/make_icons.py` 的 `PAD`、`ANCHOR`），
/// 所以按 `overscan` 放大画、再把物体挪回中间：布局上仍占 `size` 见方，阴影自然地淡出到格子外面，不会被截成直角。
struct ModeIcon: View {
    let mode: AlbumMode
    let size: CGFloat

    /// (1 − 2 × 0.08) / (1 − 2 × 0.22)：物体和以前（留边 8%）一样大。
    static let overscan: CGFloat = 1.5
    /// 渲染时物体放在画面 45% 处（阴影往右下落），这里挪回中心。
    static let anchorShift: CGFloat = 0.05

    var body: some View {
        Group {
            if BundledImage.has(mode.iconName) {
                let drawn = size * Self.overscan
                Image(mode.iconName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: drawn, height: drawn)
                    .offset(x: drawn * Self.anchorShift, y: drawn * Self.anchorShift)
                    .allowsHitTesting(false)
            } else {
                Image(systemName: mode.symbol)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(Palette.walnutLight)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 搜索

/// 象牙白胶囊搜索框（内阴影 + 放大镜）。⌘F 聚焦，Esc 清空。
private struct AlbumSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            TextField("", text: $text, prompt: Text("搜索题字、标签、地点、胶卷、日期…").foregroundColor(Palette.inkSoft.opacity(0.75)))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .focused(focused)
                .onExitCommand { text = "" }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 260, height: 30)
        .background(
            Capsule()
                .fill(Palette.ivoryLight.shadow(.inner(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)))
        )
        .overlay(
            Capsule()
                .stroke(focused.wrappedValue ? Palette.terracotta.opacity(0.55) : Palette.hairline, lineWidth: focused.wrappedValue ? 1.2 : 0.6)
        )
        .animation(.easeOut(duration: 0.15), value: focused.wrappedValue)
    }
}

// MARK: - 冲印照片、归档方式

/// 黄铜小圆钮的样子（「＋」和齿轮共用）。
private struct BrassKnob: View {
    let symbol: String
    let hovering: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.walnutDeep)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 0.8).padding(0.8))
            .overlay(Circle().stroke(Palette.walnut.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.28), radius: 0.8, y: 0.8)
            .shadow(color: .black.opacity(hovering ? 0.2 : 0.12), radius: hovering ? 6 : 4, y: hovering ? 4 : 2)
            .scaleEffect(hovering ? 1.05 : 1)
    }
}

/// 黄铜小圆钮「＋」：从文件或「照片」图库冲印。
private struct ImportButton: View {
    @State private var hovering = false

    var body: some View {
        Button {
            let menu = NSMenu()
            menu.addItem(ActionMenuItem(title: String(localized: "从文件冲印…")) { PhotoImport.chooseFiles() })
            menu.addItem(ActionMenuItem(title: String(localized: "从「照片」图库冲印…")) { PhotoImport.choosePhotosLibrary() })
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } label: {
            BrassKnob(symbol: "plus", hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { hovering = inside }
        }
        .help("冲印照片（⌘O）")
    }
}

/// 黄铜小圆钮「齿轮」：卡片盒按题字首字母，还是按拍摄的年 / 月 / 日归档（分隔卡上的标签跟着换）。
private struct IndexModeButton: View {
    @Binding var indexMode: CardIndexMode
    let onChoose: () -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            let menu = NSMenu()
            menu.addItem(NSMenuItem.sectionHeader(title: String(localized: "卡片盒归档")))
            for choice in CardIndexMode.allCases {
                let item = ActionMenuItem(title: choice.menuTitle) {
                    indexMode = choice
                    onChoose()
                }
                item.image = NSImage(systemSymbolName: choice.symbol, accessibilityDescription: nil)
                item.state = choice == indexMode ? .on : .off
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } label: {
            BrassKnob(symbol: "gearshape.fill", hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { hovering = inside }
        }
        .help("卡片盒归档：按首字母或按年 / 月 / 日")
    }
}

// MARK: - 红绿灯

/// 把红绿灯挪到顶栏的垂直中线上（透明标题栏 + 全尺寸内容的窗口）。
///
/// 做法与 Electron 的 `trafficLightPosition` 相同：加高标题栏容器、重新摆放三个按钮；
/// 窗口尺寸、全屏、主窗口状态变化后 AppKit 会把它们摆回去，所以在这些时刻重新摆一次。
@MainActor
enum TrafficLights {
    static func attach(to window: NSWindow, height: CGFloat, leading: CGFloat) {
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didChangeScreenNotification,
            NSWindow.didDeminiaturizeNotification
        ]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated {
                    guard let window else { return }
                    layout(window, height: height, leading: leading)
                }
            }
        }
        layout(window, height: height, leading: leading)
        DispatchQueue.main.async { [weak window] in
            MainActor.assumeIsolated {
                guard let window else { return }
                layout(window, height: height, leading: leading)
            }
        }
    }

    static func layout(_ window: NSWindow, height: CGFloat, leading: CGFloat) {
        guard !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let mini = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let container = close.superview?.superview else { return }
        var frame = container.frame
        frame.size.height = height
        frame.origin.y = window.frame.height - height
        container.frame = frame
        var spacing = mini.frame.minX - close.frame.minX
        if spacing < 16 || spacing > 30 { spacing = 20 }
        for (index, button) in [close, mini, zoom].enumerated() {
            button.setFrameOrigin(NSPoint(x: leading + CGFloat(index) * spacing, y: (height - button.frame.height) / 2))
        }
    }
}
