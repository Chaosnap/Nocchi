import AppKit
import NocchiKit
import SwiftUI

/// 大头贴机的「选相框」：黄铜包边的橱窗里挂着这一款的样张（暖灰占位格合成），两边黄铜箭头换相框；
/// 下面是名字、页码、两个镀铬拨动开关（四格条 / 四宫格、黑白 / 彩色）、用哪卷胶卷，和一颗会发光的「开始」。
struct BoothFrameChooser: View {
    @ObservedObject var booth: PhotoBoothController
    @ObservedObject var previews: TemplatePreviewStore

    private var request: TemplatePreviewStore.Request {
        booth.previewRequest(for: booth.selectedTemplate)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 22) {
                BrassArrowButton(pointsLeft: true) { booth.step(-1) }
                SampleShowcase(
                    image: previews.image(request),
                    format: booth.boothFormat,
                    key: "\(booth.selectedTemplate.id)|\(booth.boothFormat.rawValue)|\(request.stockID)",
                    direction: booth.lastStep
                )
                BrassArrowButton(pointsLeft: false) { booth.step(1) }
            }

            VStack(spacing: 4) {
                Text(booth.selectedTemplate.name)
                    .font(RetroFont.typewriter(22, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(booth.selectedTemplate.note)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
            }
            .id(booth.selectedTemplate.id)
            .transition(.opacity)

            PageDots(count: booth.templates.count, index: booth.templateIndex) { booth.select(index: $0) }

            HStack(spacing: 22) {
                LeverSwitch(left: "四格条", right: "四宫格", isRight: booth.boothFormat == .boothGrid) { right in
                    booth.setFormat(right ? .boothGrid : .boothStrip)
                }
                LeverSwitch(left: "黑白", right: "彩色", isRight: !booth.monochrome) { right in
                    booth.setMonochrome(!right)
                }
            }

            Text("胶卷 · \(booth.stock.name)")
                .font(RetroFont.typewriter(12))
                .foregroundStyle(Palette.inkSoft)

            GlowStartButton { booth.confirmFrame() }
                .padding(.top, 2)
        }
        .padding(.horizontal, 30)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(MachineFace())
        .task(id: "\(booth.boothFormat.rawValue)|\(booth.stock.id)") {
            await previews.prefetch(booth.prefetchRequests())
        }
    }
}

// MARK: - 机身面板

/// 象牙白搪瓷面板（和取景框同一种外壳），四角四颗黄铜螺丝。
private struct MachineFace: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(LinearGradient(colors: [Palette.ivoryLight, Palette.ivoryShade], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .black.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) { Screw().padding(14) }
            .overlay(alignment: .topTrailing) { Screw().padding(14) }
            .overlay(alignment: .bottomLeading) { Screw().padding(14) }
            .overlay(alignment: .bottomTrailing) { Screw().padding(14) }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
    }
}

private struct Screw: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x7E6236)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle()
                .fill(Color(hex: 0x5A4526).opacity(0.7))
                .frame(width: 6, height: 1.2)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: 9, height: 9)
        .shadow(color: .black.opacity(0.3), radius: 0.6, y: 0.5)
    }
}

// MARK: - 橱窗

/// 黄铜包边、暖光照着的橱窗，样张用小铜夹挂在里面。换相框时样张从切换的方向滑进来。
private struct SampleShowcase: View {
    let image: CGImage?
    let format: FilmFormat
    let key: String
    let direction: Int

    private let windowSize = CGSize(width: 310, height: 314)
    private let maxPrint = CGSize(width: 244, height: 268)

    private var printSize: CGSize {
        let aspect = format.layout.aspect
        var height = maxPrint.height
        var width = height * aspect
        if width > maxPrint.width {
            width = maxPrint.width
            height = width / aspect
        }
        return CGSize(width: width, height: height)
    }

    var body: some View {
        ZStack {
            // 橱窗里面：深色绒布 + 顶上一盏暖灯。
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x3A2C22), Color(hex: 0x1C1511)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RadialGradient(colors: [Color(hex: 0xFFE2B8, opacity: 0.32), .clear], center: UnitPoint(x: 0.42, y: 0.02), startRadius: 4, endRadius: 280))

            sample
                .id(key)
                .transition(.asymmetric(
                    insertion: .offset(x: CGFloat(direction) * 70).combined(with: .opacity),
                    removal: .offset(x: CGFloat(-direction) * 70).combined(with: .opacity)
                ))

            // 玻璃上的一道斜反光。
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.09), .clear, .clear, .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .allowsHitTesting(false)
            // 内凹阴影。
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.55), lineWidth: 6)
                .blur(radius: 5)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            // 黄铜包边。
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x7E6236), Palette.brass], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .inset(by: 4)
                .stroke(Color.black.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
    }

    @ViewBuilder
    private var sample: some View {
        let size = printSize
        ZStack(alignment: .top) {
            Group {
                if let image {
                    Image(decorative: image, scale: 2)
                        .resizable()
                        .interpolation(.high)
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Palette.paperDeep.opacity(0.85))
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(0.45), radius: 1.5, x: 0.5, y: 1)
            .shadow(color: .black.opacity(0.35), radius: 14, x: 4, y: 10)

            BrassClip()
                .offset(y: -9)
        }
        .rotationEffect(.degrees(-1.2))
        .offset(y: 8)
    }
}

/// 挂样张的小铜夹。
private struct BrassClip: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x8A6B3C)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 18)
            Rectangle()
                .fill(Color(hex: 0x5A4526).opacity(0.45))
                .frame(width: 30, height: 0.8)
                .offset(y: 6)
            Capsule()
                .fill(LinearGradient(colors: [Palette.chromeLight, Palette.chromeDark], startPoint: .top, endPoint: .bottom))
                .frame(width: 12, height: 4)
                .offset(y: -3)
        }
        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.25), radius: 4, x: 2, y: 3)
    }
}

// MARK: - 黄铜箭头

private struct BrassArrowButton: View {
    let pointsLeft: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.brassLight, Palette.brass, Color(hex: 0x7E6236)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .clear, .black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                Circle()
                    .inset(by: 6)
                    .strokeBorder(Color(hex: 0x6B532E).opacity(0.45), lineWidth: 0.8)
                Image(systemName: pointsLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x4A3A20))
                    .shadow(color: .white.opacity(0.55), radius: 0, x: 0.6, y: 0.8)
                    .offset(x: pointsLeft ? -1 : 1)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.25), radius: 10, y: 7)
            .contentShape(Circle())
        }
        .buttonStyle(BoothPressStyle())
        .help(pointsLeft ? "上一款（←）" : "下一款（→）")
    }
}

// MARK: - 页码

private struct PageDots: View {
    let count: Int
    let index: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Palette.terracotta : Palette.inkSoft.opacity(0.28))
                    .frame(width: i == index ? 7 : 5, height: i == index ? 7 : 5)
                    .frame(width: 10, height: 10)
                    .contentShape(Rectangle())
                    .onTapGesture { select(i) }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
    }
}

// MARK: - 拨动开关

/// 镀铬拨杆开关：底座螺母 + 斜着的拨杆，左右两边是打字机字的刻字。点哪边拨到哪边，点拨杆来回拨。
private struct LeverSwitch: View {
    let left: String
    let right: String
    let isRight: Bool
    let change: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            label(left, active: !isRight) { change(false) }
            Button { change(!isRight) } label: { lever }
                .buttonStyle(.plain)
            label(right, active: isRight) { change(true) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Palette.ivoryShade.opacity(0.55), Palette.ivoryLight], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.black.opacity(0.14), .white.opacity(0.7)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
    }

    private func label(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(RetroFont.typewriter(13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Palette.ink : Palette.inkSoft.opacity(0.7))
                .frame(minWidth: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var lever: some View {
        ZStack {
            // 底座螺母（六角的感觉用一圈暗边表示）。
            Circle()
                .fill(RadialGradient(colors: [Palette.chromeLight, Palette.chromeDark], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 16))
                .frame(width: 26, height: 26)
            Circle()
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.8)
                .frame(width: 26, height: 26)
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 9, height: 9)
            // 拨杆：从中心伸出去，绕中心转。
            ZStack(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: [Palette.chromeLight, Color(white: 0.6), Palette.chromeLight.opacity(0.95)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 7, height: 22)
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(white: 0.64)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0.5, endRadius: 7))
                    .frame(width: 11, height: 11)
                    .offset(y: -3)
            }
            .frame(width: 26, height: 44, alignment: .top)
            .rotationEffect(.degrees(isRight ? 34 : -34))
            .shadow(color: .black.opacity(0.35), radius: 1.5, x: 1.5, y: 2)
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isRight)
    }
}

// MARK: - 「开始」

/// 一颗会呼吸发光的陶土橙灯罩按钮，镀铬外圈。按下去有投币声（由大头贴机播放）。
private struct GlowStartButton: View {
    let action: () -> Void
    @State private var glowing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Palette.chromeLight, Palette.chromeDark, Palette.chromeLight], startPoint: .top, endPoint: .bottom))
                    .frame(width: 178, height: 60)
                Capsule()
                    .fill(RadialGradient(
                        colors: [Color(hex: 0xFFD7B5), Palette.terracottaLight, Palette.terracotta, Color(hex: 0x8E3A24)],
                        center: UnitPoint(x: 0.5, y: 0.3),
                        startRadius: 2,
                        endRadius: 96
                    ))
                    .frame(width: 166, height: 48)
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 136, height: 18)
                    .offset(y: -12)
                Text("开始")
                    .font(RetroFont.serif(22, weight: .bold))
                    .tracking(8)
                    .foregroundStyle(Palette.ivoryLight)
                    .shadow(color: Color(hex: 0x6A2414).opacity(0.75), radius: 0, y: 1)
            }
            .shadow(color: Palette.terracottaLight.opacity(glowing ? 0.9 : 0.35), radius: glowing ? 22 : 10)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
            .contentShape(Capsule())
        }
        .buttonStyle(BoothPressStyle())
        .help("投币开始（Return）")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

/// 按下去微微下沉。
struct BoothPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
