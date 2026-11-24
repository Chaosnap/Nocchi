import AppKit
import NocchiKit
import SwiftUI

/// 装饰台窗口：拍完之后给照片涂鸦、贴贴纸、换模板、写题字、做分享海报。
///
/// 入口：桌面相片右键「装饰…」与双击；相册各视图右键「装饰…」与双击；
/// 设置里「拍完后自动打开装饰台」开着时，相片显影完成后自动打开。同一时间只开一张。
@MainActor
final class DecorateDesk {
    static let shared = DecorateDesk()

    private var window: NSWindow?
    private var session: DecorateSession?
    private var closeObserver: NSObjectProtocol?

    private init() {}

    var isOpen: Bool { window?.isVisible == true }

    func open(_ record: PhotoRecord) {
        // 用最新的记录（桌面上的那张可能刚写过字、挪过位置）。
        let current = DesktopBoard.shared.controllers[record.id]?.model.record
            ?? Services.library.record(id: record.id)
            ?? record
        if let window, let session, session.record.id == current.id {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        close()
        let stock = AppModel.shared.stock(id: current.stockID)
        let desktopImages = DesktopBoard.shared.controllers[current.id]?.model.displayImages
        Task {
            let images: [CGImage]
            if let desktopImages, !desktopImages.isEmpty {
                images = desktopImages
            } else {
                images = await Self.loadImages(for: current)
            }
            guard !images.isEmpty else {
                NSSound.beep()
                return
            }
            self.present(DecorateSession(record: current, images: images, stockPaper: stock.paper))
        }
    }

    /// 底片 + 色块（和桌面上、成片里一致）。
    private static func loadImages(for record: PhotoRecord) async -> [CGImage] {
        await Task.detached(priority: .userInitiated) {
            let negatives = Services.library.loadNegatives(of: record)
            guard !record.blotches.isEmpty else { return negatives }
            return negatives.enumerated().map { pair in
                Services.processor.applyingBlotches(record.blotches(forFrame: pair.offset), to: pair.element) ?? pair.element
            }
        }.value
    }

    private func present(_ session: DecorateSession) {
        NotchController.shared.collapse()
        session.onClose = { [weak self] in self?.close() }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "装饰台"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Palette.walnutDeep)
        window.contentMinSize = NSSize(width: 980, height: 700)
        window.contentView = NSHostingView(rootView: DecorateDeskView(session: session))
        window.center()
        window.setFrameAutosaveName("NocchiDecorateDesk")
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.window = nil
                self?.session = nil
            }
        }
        self.window = window
        self.session = session
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        window?.close()
        window = nil
        session = nil
    }
}

// MARK: - 窗口内容

struct DecorateDeskView: View {
    @ObservedObject var session: DecorateSession

    var body: some View {
        ZStack {
            DeskSurface()
            HStack(spacing: 0) {
                ToolRail(session: session)
                    .padding(.leading, 18)
                    .padding(.vertical, 48)
                VStack(spacing: 0) {
                    DeskTitle(record: session.record)
                        .frame(height: 52)
                    GeometryReader { geo in
                        let width = Self.paperWidth(for: session.record.layout, in: geo.size)
                        ZStack {
                            LampGlow()
                            PaperStage(session: session, width: width)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    DeskActions(session: session)
                        .padding(.bottom, 18)
                }
                Inspector(session: session)
                    .frame(width: 330)
            }
        }
        .ignoresSafeArea()
        .background { DeskShortcuts(session: session) }
    }

    /// 相纸按窗口适配：拍立得最大约 560pt 宽，长条按高度收。
    static func paperWidth(for layout: PaperLayout, in size: CGSize) -> CGFloat {
        let paper = layout.paperSize
        let aspect = paper.height > 0 ? paper.width / paper.height : 1
        let byHeight = (size.height - 40) * aspect
        let byWidth = size.width - 80
        return max(120, min(560 * max(1, aspect * 1.1), byWidth, byHeight))
    }
}

/// 顶部：「装饰台」+ 这张照片的胶卷与日期（红绿灯在左边）。
private struct DeskTitle: View {
    let record: PhotoRecord

    var body: some View {
        HStack(spacing: 10) {
            Text("装饰台")
                .font(RetroFont.serif(15, weight: .semibold))
                .foregroundStyle(Palette.ivoryLight)
            Text("\(record.stockName) · \(record.dateText)")
                .font(RetroFont.typewriter(12))
                .foregroundStyle(Palette.ivoryLight.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .background(WindowDragArea())
    }
}

/// 深色胡桃木桌面。
private struct DeskSurface: View {
    var body: some View {
        ZStack {
            Palette.walnutDeep
            if BundledImage.has("WoodTexture") {
                Image("WoodTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.45)
            }
            Color.black.opacity(0.28)
        }
    }
}

/// 台灯光：相纸周围一团暖光。
private struct LampGlow: View {
    var body: some View {
        RadialGradient(
            colors: [Color(hex: 0xFFE2B0, opacity: 0.42), Color(hex: 0xFFC77A, opacity: 0.12), .clear],
            center: UnitPoint(x: 0.46, y: 0.44),
            startRadius: 10,
            endRadius: 520
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

// MARK: - 工具托盘

/// 左边的皮革工具托盘：选择 / 四种笔 / 橡皮 ｜ 8 个珐琅颜料 ｜ 粗细 ｜ 撤销 / 重做。
private struct ToolRail: View {
    @ObservedObject var session: DecorateSession

    var body: some View {
        VStack(spacing: 6) {
            RailButton(symbol: "cursorarrow", help: "选择、移动贴纸", selected: session.tool == .select) {
                session.tool = .select
            }
            ForEach(InkTool.allCases) { ink in
                RailButton(symbol: ink.symbolName, help: ink.displayName, selected: session.tool == .ink(ink)) {
                    session.tool = .ink(ink)
                    session.selectedSticker = nil
                }
            }
            RailButton(symbol: "eraser", help: "橡皮：点哪条笔画删哪条", selected: session.tool == .eraser) {
                session.tool = .eraser
                session.selectedSticker = nil
            }
            RailDivider()
            ForEach(DecorateSession.paints) { paint in
                PaintDot(hex: paint.hex, name: paint.name, selected: session.paint == paint.hex) {
                    session.paint = paint.hex
                    if session.tool == .select || session.tool == .eraser {
                        session.tool = .ink(.pen)
                    }
                }
            }
            RailDivider()
            ThicknessDial(value: $session.thickness)
            RailDivider()
            RailButton(symbol: "arrow.uturn.backward", help: "撤销（⌘Z）", selected: false, enabled: session.canUndo) {
                session.undo()
            }
            RailButton(symbol: "arrow.uturn.forward", help: "重做（⇧⌘Z）", selected: false, enabled: session.canRedo) {
                session.redo()
            }
        }
        .padding(.vertical, 14)
        .frame(width: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x3A2E26), Palette.leather], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: 0xC9A97A, opacity: 0.45), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2.5]))
                .padding(5)
        )
        .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.35), radius: 14, x: 3, y: 8)
    }
}

private struct RailButton: View {
    let symbol: String
    let help: String
    let selected: Bool
    var enabled = true
    let action: () -> Void

    init(symbol: String, help: String, selected: Bool, enabled: Bool = true, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.selected = selected
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Palette.walnutDeep : Palette.ivoryLight.opacity(enabled ? 0.85 : 0.3))
                .frame(width: 38, height: 30)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass], startPoint: .top, endPoint: .bottom))
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }
}

private struct PaintDot: View {
    let hex: String
    let name: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 9))
                .background(Circle().fill(Color(rgbHex: hex)))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.6))
                .padding(2)
                .overlay(Circle().stroke(Palette.brassLight, lineWidth: selected ? 1.6 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

private struct RailDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 30, height: 0.8)
            .padding(.vertical, 2)
    }
}

/// 粗细：三档小圆点。
private struct ThicknessDial: View {
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 2) {
            ForEach([0.6, 1.0, 1.7], id: \.self) { level in
                Button {
                    value = level
                } label: {
                    Circle()
                        .fill(Palette.ivoryLight.opacity(abs(value - level) < 0.01 ? 0.95 : 0.4))
                        .frame(width: 5 + level * 6, height: 5 + level * 6)
                        .frame(width: 30, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(level < 1 ? "细" : (level > 1 ? "粗" : "中"))
            }
        }
    }
}

// MARK: - 底部按钮与快捷键

private struct DeskActions: View {
    @ObservedObject var session: DecorateSession

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            // 不绑 Esc：Esc 只用来取消选中贴纸，不能一按就丢掉所有装饰。
            Button("取消") { session.onClose?() }
                .buttonStyle(DeskButtonStyle(primary: false))
            Button {
                Task {
                    await session.save()
                    session.onClose?()
                }
            } label: {
                HStack(spacing: 6) {
                    if session.saving {
                        ProgressView().controlSize(.small)
                    }
                    Text("完成")
                }
            }
            .buttonStyle(DeskButtonStyle(primary: true))
            .disabled(session.saving)
            Spacer()
        }
    }
}

private struct DeskButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(primary ? Color.white : Palette.ink)
            .padding(.horizontal, 26)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(primary
                          ? LinearGradient(colors: [Palette.terracottaLight, Palette.terracotta], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Palette.ivoryLight, Palette.ivory], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8).padding(0.8))
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}

/// ⌘Z 撤销、⇧⌘Z 重做、⌘S 完成（看不见的按钮，只为了快捷键）。
private struct DeskShortcuts: View {
    @ObservedObject var session: DecorateSession

    var body: some View {
        ZStack {
            Button("撤销") { session.undo() }
                .keyboardShortcut("z", modifiers: .command)
            Button("重做") { session.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            Button("完成") {
                Task {
                    await session.save()
                    session.onClose?()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }
}

extension Color {
    /// 「#RRGGBB」→ 颜色（解析失败时用墨色）。
    init(rgbHex hex: String) {
        if let rgb = RGB(hex: hex) {
            self.init(.sRGB, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z), opacity: 1)
        } else {
            self = Palette.ink
        }
    }
}
