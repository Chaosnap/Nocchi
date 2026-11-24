import AVFoundation
import NocchiKit
import SwiftUI

/// 刘海面板里的全部内容：一个会变形的黑色岛。
struct NotchRootView: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraService

    private let ear: CGFloat = 12
    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)

    var body: some View {
        let size = notch.islandSize
        let notchHeight = notch.metrics.rect.height
        ZStack(alignment: .topLeading) {
            Color.clear
            island(size: size, notchHeight: notchHeight)
                .frame(width: size.width + 2 * ear, height: size.height)
                .position(x: notch.islandCenterX, y: size.height / 2)
        }
        .frame(width: notch.panelSize.width, height: notch.panelSize.height, alignment: .topLeading)
        .animation(spring, value: notch.mode)
        .animation(spring, value: notch.slotWidth)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func island(size: CGSize, notchHeight: CGFloat) -> some View {
        let shape = NotchShape(earRadius: notch.mode == .idle ? 6 : ear, bottomRadius: bottomRadius)
        ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(notch.mode == .idle ? 0 : 0.35), radius: 14, x: 0, y: 8)
            content(notchHeight: notchHeight)
                .padding(.horizontal, ear)
                .frame(width: size.width + 2 * ear, height: size.height, alignment: .top)
                .clipShape(shape)
        }
        .opacity(notch.isIslandVisible ? 1 : 0)
    }

    private var bottomRadius: CGFloat {
        switch notch.mode {
        case .idle: return 10
        case .hover: return 26
        case .selfie: return 34
        case .ejecting: return 9
        case .toast: return notch.toastStyle == .banner ? 22 : 14
        case .shelf: return 30
        case .dropTarget: return 26
        }
    }

    @ViewBuilder
    private func content(notchHeight: CGFloat) -> some View {
        switch notch.mode {
        case .idle:
            Color.clear
        case .hover:
            HoverPanel(notch: notch, model: model, notchHeight: notchHeight)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        case .selfie:
            SelfiePanel(notch: notch, camera: camera, notchHeight: notchHeight)
                .transition(.opacity)
        case .ejecting:
            VStack {
                Spacer()
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: notch.slotWidth + 6, height: 4)
                    .padding(.bottom, 3)
            }
        case .toast:
            ToastBand(notch: notch, notchHeight: notchHeight)
                .transition(.opacity)
        case .shelf:
            ShelfPanel(notch: notch, shelf: NotchShelf.shared, notchHeight: notchHeight)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        case .dropTarget:
            DropTargetPanel(notch: notch, notchHeight: notchHeight)
                .transition(.opacity)
        }
    }
}

// MARK: - Hover

private struct HoverPanel: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var model: AppModel
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: model.currentBody.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(model.currentBody.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer(minLength: notch.metrics.rect.width + 24)
                FilmSwatch(stock: model.currentStock)
                    .frame(width: 26, height: 10)
                Text("\(model.currentStock.name) · \(model.roll.counterText)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 18)
            .frame(height: notchHeight)

            HStack(spacing: 10) {
                NotchActionButton(symbol: "camera.viewfinder", title: "屏幕快门", hint: "⌃⌥⌘S") {
                    Darkroom.shared.screenShutter()
                }
                NotchActionButton(symbol: "face.smiling", title: "自拍", hint: "⌃⌥⌘F") {
                    notch.enterSelfie()
                }
                NotchActionButton(symbol: "square.grid.2x2", title: "大头贴", hint: "⌃⌥⌘B") {
                    PhotoBoothController.shared.start()
                }
                if !NotchShelf.shared.isEmpty {
                    NotchActionButton(symbol: "tray.full.fill", title: "暂存", hint: "\(NotchShelf.shared.items.count) 张") {
                        notch.openShelf()
                    }
                }
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 52)
                VStack(spacing: 6) {
                    Menu {
                        ForEach(model.stocks) { stock in
                            Button("\(stock.name)  \(stock.summary)") { model.stockID = stock.id }
                        }
                    } label: {
                        Label("换胶卷", systemImage: "film")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .fixedSize()
                    HStack(spacing: 12) {
                        SmallIconButton(symbol: "rectangle.stack", help: "相册") { WindowManager.shared.showAlbum() }
                        SmallIconButton(symbol: model.quietMode ? "speaker.slash.fill" : "speaker.wave.2.fill", help: "安静模式") {
                            model.quietMode.toggle()
                        }
                        SmallIconButton(symbol: "gearshape.fill", help: "设置") { WindowManager.shared.showSettings() }
                    }
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }
}

private struct NotchActionButton: View {
    let symbol: String
    let title: String
    let hint: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(hint)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .opacity(0.5)
            }
            .foregroundStyle(.white)
            .frame(width: 92, height: 76)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.16 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct SmallIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// 胶卷色卡（三色渐变）。
struct FilmSwatch: View {
    let stock: FilmStock

    var body: some View {
        let colors = stock.swatch.compactMap { RGB(hex: $0) }.map { Color(rgb: $0) }
        Capsule()
            .fill(LinearGradient(colors: colors.isEmpty ? [.gray] : colors, startPoint: .leading, endPoint: .trailing))
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Toast

/// 提示：紧凑（刘海两侧各伸出一小截）或横幅（向下长出一条），都和灵动岛一个比例。
private struct ToastBand: View {
    @ObservedObject var notch: NotchController
    let notchHeight: CGFloat

    var body: some View {
        switch notch.toastStyle {
        case .compact:
            compact
        case .banner:
            banner
        }
    }

    private var icon: some View {
        Image(systemName: notch.toastSymbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.terracottaLight)
    }

    private var compact: some View {
        HStack(spacing: 0) {
            icon
                .frame(maxWidth: .infinity)
            Spacer(minLength: notch.metrics.rect.width)
            HStack(spacing: 5) {
                if notch.toastLive {
                    LiveDot()
                }
                Text(notch.toastText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: notchHeight)
    }

    private var banner: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: notchHeight)
            HStack(spacing: 8) {
                icon
                Text(notch.toastText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
    }
}

/// 「营业中」的绿色小灯（呼吸）。
private struct LiveDot: View {
    @State private var glow = false

    var body: some View {
        Circle()
            .fill(Color(red: 0.36, green: 0.84, blue: 0.47))
            .frame(width: 6, height: 6)
            .shadow(color: Color(red: 0.36, green: 0.84, blue: 0.47).opacity(glow ? 0.9 : 0.3), radius: glow ? 4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

// MARK: - Selfie

/// 自拍取景器：刘海那一行 + 镜头 + 按钮行。每一段的高度都来自 `SelfieLayout`，
/// 岛的高度由同一组常量推出来，所以按钮行永远完整可见。
private struct SelfiePanel: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var camera: CameraService
    @ObservedObject var model = AppModel.shared
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: notchHeight)
            lens
                .frame(width: SelfieLayout.lens, height: SelfieLayout.lens)
                .padding(.top, SelfieLayout.topGap)
            controls
                .frame(height: SelfieLayout.row)
                .padding(.top, SelfieLayout.rowGap)
            Spacer(minLength: SelfieLayout.bottomInset)
        }
    }

    private var header: some View {
        HStack {
            Text("自拍 · \(model.currentStock.name)")
            Spacer(minLength: notch.metrics.rect.width + 24)
            Text("空格拍照 · Esc 退出")
                .opacity(0.6)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 18)
    }

    private var lens: some View {
        ZStack {
            LensRing()
            CameraPreview(session: camera.session, mirrored: model.mirrorSelfie, isRunning: camera.isRunning)
                .frame(width: SelfieLayout.viewfinder, height: SelfieLayout.viewfinder)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 3))
            if !camera.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
            if let n = notch.countdown {
                Text("\(n)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            RoundControlButton(symbol: "xmark", isOn: false, help: "退出自拍（Esc）") {
                notch.exitSelfie()
            }
            ShutterButton(enabled: camera.isRunning && !notch.isCapturing) {
                notch.selfieShutter()
            }
            RoundControlButton(symbol: "timer", isOn: model.selfieCountdown, help: "自拍倒数 3 秒") {
                model.selfieCountdown.toggle()
            }
        }
    }
}

/// 快门键：象牙白外圈 + 陶土橙内钮，按下时微微下沉。
private struct ShutterButton: View {
    let enabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.ivoryLight, Palette.ivoryShade], startPoint: .top, endPoint: .bottom))
                Circle()
                    .fill(RadialGradient(colors: [Palette.terracottaLight, Palette.terracotta], center: .topLeading, startRadius: 2, endRadius: 44))
                    .padding(7)
                Circle()
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    .padding(7)
                Circle()
                    .trim(from: 0.55, to: 0.95)
                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .padding(10)
            }
            .frame(width: SelfieLayout.row, height: SelfieLayout.row)
            .shadow(color: Palette.terracotta.opacity(hovering && enabled ? 0.6 : 0.35), radius: hovering ? 12 : 8)
            .scaleEffect(hovering && enabled ? 1.04 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        }
        .buttonStyle(PressSinkStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .onHover { hovering = $0 }
        .help("拍照（空格）")
    }
}

/// 自拍取景器两侧的圆形小按钮（关闭、倒数）。
private struct RoundControlButton: View {
    let symbol: String
    let isOn: Bool
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isOn ? Palette.charcoal : .white)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isOn ? AnyShapeStyle(Palette.terracottaLight) : AnyShapeStyle(Color.white.opacity(hovering ? 0.2 : 0.12)))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(PressSinkStyle())
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// 按下时轻轻下沉、变暗。
private struct PressSinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 镜头外圈：象牙白机身上的黑色多圈纹镜筒 + 一道细铬圈（取景器在最里面）。
private struct LensRing: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.ivory)
            Circle()
                .fill(AngularGradient(colors: [Palette.chromeLight, Palette.chromeDark, Palette.chromeLight, Palette.chromeDark, Palette.chromeLight], center: .center))
                .padding(6)
            Circle()
                .fill(Palette.lensBlack)
                .padding(10)
            ForEach(0..<7, id: \.self) { ring in
                Circle()
                    .stroke(Color.white.opacity(ring.isMultiple(of: 2) ? 0.07 : 0.03), lineWidth: 1)
                    .padding(13 + CGFloat(ring) * 2.6)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 10, y: 4)
    }
}

extension Color {
    init(rgb: RGB, opacity: Double = 1) {
        self.init(.sRGB, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z), opacity: opacity)
    }

    init(hex: String, fallback: RGB = RGB(0.17, 0.16, 0.16)) {
        self.init(rgb: RGB(hex: hex) ?? fallback)
    }
}
