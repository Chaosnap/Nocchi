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
        case .toast: return 14
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

private struct ToastBand: View {
    @ObservedObject var notch: NotchController
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: notch.toastSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.terracottaLight)
                .frame(maxWidth: .infinity)
            Spacer(minLength: notch.metrics.rect.width)
            Text(notch.toastText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .frame(height: notchHeight)
    }
}

// MARK: - Selfie

private struct SelfiePanel: View {
    @ObservedObject var notch: NotchController
    @ObservedObject var camera: CameraService
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("自拍 · 即显相机")
                Spacer(minLength: notch.metrics.rect.width + 24)
                Text("空格拍照 · Esc 取消")
                    .opacity(0.6)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 18)
            .frame(height: notchHeight)

            ZStack {
                LensRing()
                    .frame(width: 236, height: 236)
                CameraPreview(session: camera.session, mirrored: true, isRunning: camera.isRunning)
                    .frame(width: 196, height: 196)
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
            .padding(.top, 8)

            HStack(spacing: 28) {
                Button {
                    notch.exitSelfie()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                Button {
                    notch.selfieShutter()
                } label: {
                    ZStack {
                        Circle().fill(Palette.ivory)
                        Circle()
                            .fill(RadialGradient(colors: [Palette.terracottaLight, Palette.terracotta], center: .topLeading, startRadius: 2, endRadius: 40))
                            .padding(6)
                        Circle().stroke(Color.black.opacity(0.18), lineWidth: 1).padding(6)
                    }
                    .frame(width: 54, height: 54)
                    .shadow(color: Palette.terracotta.opacity(0.45), radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(!camera.isRunning || notch.isCapturing)

                Toggle(isOn: Binding(get: { AppModel.shared.selfieCountdown }, set: { AppModel.shared.selfieCountdown = $0 })) {
                    Image(systemName: "timer")
                }
                .toggleStyle(.button)
                .help("自拍倒数 3 秒")
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
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
