import NocchiKit
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// 卡片盒用到的颜色（和 App 里的 `Palette` 同一套值）。
enum CardInk {
    static let paper = Color(cardHex: 0xF4F0E6)
    static let photoWell = Color(cardHex: 0xE9E3D6)
    static let ink = Color(cardHex: 0x2E2924)
    static let inkSoft = Color(cardHex: 0x7A6F64)
    static let hairline = Color(cardHex: 0xD8CFBF)
    static let accent = Color(cardHex: 0xC4593B)
    static let rule = Color(cardHex: 0xB23A2A)
    static let ruleBlue = Color(cardHex: 0x6F8FB8)
    static let ivory = Color(cardHex: 0xECE6DA)
    static let ivoryLight = Color(cardHex: 0xF2EEE6)
}

extension Color {
    init(cardHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// App 资源目录（`Shared/Art.xcassets`）里有没有这张图。
@MainActor
enum BundledArt {
    private static var known: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let cached = known[name] { return cached }
        #if canImport(AppKit)
        let found = NSImage(named: name) != nil
        #elseif canImport(UIKit)
        let found = UIImage(named: name) != nil
        #else
        let found = false
        #endif
        known[name] = found
        return found
    }
}

// MARK: - 盒子

/// 一张卡片盒渲染图（和热点同一画布），缺图时画一个简单的木盒。
struct BoxArt: View {
    let name: String
    let stage: CardBoxStage
    let fallback: Bool

    var body: some View {
        Group {
            if BundledArt.has(name) {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else if fallback {
                FallbackBox()
            } else {
                Color.clear
            }
        }
        .frame(width: stage.imageFrame.width, height: stage.imageFrame.height)
        .position(x: stage.imageFrame.midX, y: stage.imageFrame.midY)
    }
}

/// 渲染图缺失时的退路：一只朴素的浅木盒。
private struct FallbackBox: View {
    var body: some View {
        GeometryReader { geo in
            let b = CardBoxHotspots.boxBounds
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(cardHex: 0xF0E9DC), Color(cardHex: 0xD9D0C0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: b.width * w * 0.86, height: b.height * h * 0.5)
                    .position(x: b.midX * w, y: (b.minY + b.height * 0.36) * h)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(cardHex: 0xE2B079), Color(cardHex: 0xC98E52)], startPoint: .top, endPoint: .bottom))
                    .frame(width: b.width * w, height: b.height * h * 0.48)
                    .position(x: b.midX * w, y: (b.minY + b.height * 0.74) * h)
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 4, y: 10)
            }
        }
    }
}

/// 暖米色的无缝背景（和渲染里的地面一致，盒子周围略亮）。
struct CardBoxBackdrop: View {
    let stage: CardBoxStage

    var body: some View {
        let w = max(stage.size.width, 1)
        let h = max(stage.size.height, 1)
        let b = CardBoxHotspots.boxBounds
        let glow = stage.point(CGPoint(x: b.midX, y: b.midY))
        ZStack {
            Color(cardHex: 0xE4DED3)
            RadialGradient(
                colors: [Color(cardHex: 0xF5F0E7), Color(cardHex: 0xE4DED3, opacity: 0)],
                center: UnitPoint(x: glow.x / w, y: glow.y / h),
                startRadius: 0,
                endRadius: max(w, h) * 0.66
            )
            LinearGradient(colors: [.clear, Color.black.opacity(0.06)], startPoint: .center, endPoint: .bottom)
        }
        .frame(width: w, height: h)
    }
}

// MARK: - 照片卡片

/// 一张照片索引卡：纸色卡片、照片在上、宋体标题与打字机副标题，左上方伸出字母小标签。
struct PhotoIndexCard: View {
    let record: PhotoRecord
    let image: CGImage?
    let size: CGSize
    let lifted: Bool

    private let inset: CGFloat = 11

    var body: some View {
        let photoWidth = size.width - inset * 2
        let photoHeight = max(40, min(photoWidth, size.height - 80))
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(CardInk.photoWell)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: .black.opacity(0.2), radius: 1.2, x: 0.4, y: 0.8)
                        .padding(7)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(0.5)
                }
            }
            .frame(width: photoWidth, height: photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
            .padding(.top, inset)

            Rectangle()
                .fill(CardInk.rule.opacity(0.55))
                .frame(height: 0.8)
                .padding(.top, 10)

            Text(record.indexTitle)
                .font(.custom("Songti SC", size: 14).weight(.semibold))
                .foregroundStyle(CardInk.ink)
                .lineLimit(1)
                .padding(.top, 8)

            Text(subtitle)
                .font(.custom("American Typewriter", size: 10.5))
                .foregroundStyle(CardInk.inkSoft)
                .lineLimit(1)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(alignment: .top) {
            RuledLines(top: inset + photoHeight + 36, spacing: 17)
        }
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CardInk.paper)
        )
        .overlay(alignment: .topLeading) {
            LetterTab(letter: record.indexLetter)
                .offset(x: 16, y: -18)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.26), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(lifted ? 0.3 : 0.2), radius: lifted ? 18 : 12, x: 4, y: lifted ? 14 : 9)
    }

    private var subtitle: String {
        var parts = [record.dateText]
        if let location = record.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            parts.append(location)
        }
        parts.append(record.stockName)
        return parts.joined(separator: " · ")
    }
}

/// 索引卡下半截的淡蓝横线。
private struct RuledLines: View {
    let top: CGFloat
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            var y = top
            var path = Path()
            while y < size.height - 6 {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(CardInk.ruleBlue.opacity(0.2)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// 卡片左上方伸出来的字母标签。
private struct LetterTab: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.custom("American Typewriter", size: 13).weight(.semibold))
            .foregroundStyle(CardInk.ink)
            .frame(width: 34, height: 19)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4, style: .continuous)
                    .fill(CardInk.paper)
            )
    }
}

// MARK: - 分隔卡标签

/// 分隔卡标签上的热区：有照片的字母右上角一颗陶土橙小圆点；当前字母描一圈橙边。
struct TabHotspot: View {
    let count: Int
    let active: Bool
    let hovered: Bool
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white.opacity(hovered ? 0.2 : 0))
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(CardInk.accent.opacity(active ? 0.95 : 0), lineWidth: 1.5)
            if count > 0 {
                Circle()
                    .fill(CardInk.accent)
                    .frame(width: 5.5, height: 5.5)
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                    .offset(x: 4, y: -4)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }
}

/// 悬停在标签上时的小气泡：「W · 3 张」/「W · 空」。
struct TabChip: View {
    let letter: String
    let count: Int

    var body: some View {
        Text(count > 0 ? "\(letter) · \(count) 张" : "\(letter) · 空")
            .font(.custom("American Typewriter", size: 11.5))
            .foregroundStyle(count > 0 ? CardInk.ink : CardInk.inkSoft)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(CardInk.paper))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(CardInk.hairline, lineWidth: 0.6))
            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
            .fixedSize()
    }
}

// MARK: - 摊开区

/// 「全部放回」：象牙白的复古按键。
struct PutBackButton: View {
    let action: () -> Void
    @State private var hovering = false

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .bold))
                Text("全部放回")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(CardInk.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [CardInk.ivoryLight, CardInk.ivory], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 0.8).padding(0.6))
            .overlay(Capsule().stroke(CardInk.hairline, lineWidth: 0.6))
            .shadow(color: .black.opacity(0.24), radius: 0.8, y: 0.8)
            .shadow(color: .black.opacity(hovering ? 0.2 : 0.12), radius: hovering ? 8 : 5, y: hovering ? 5 : 3)
            .scaleEffect(hovering ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovering = inside }
        }
        .help("把摊开的卡片全部放回盒子")
    }
}

/// 扇形下面的一行打字机小字。
struct SpreadCaption: View {
    let text: String
    let more: Bool

    var body: some View {
        Text(more ? "\(text) · 左右拖动翻看" : text)
            .font(.custom("American Typewriter", size: 11.5))
            .foregroundStyle(CardInk.inkSoft)
            .tracking(0.4)
            .fixedSize()
    }
}

/// 盒子是空的：一张打字机索引卡。
struct EmptyBoxCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡片盒还是空的")
                .font(.custom("Songti SC", size: 17).weight(.semibold))
                .foregroundStyle(CardInk.ink)
            Rectangle()
                .fill(CardInk.rule.opacity(0.55))
                .frame(height: 0.8)
            Text("拍下的照片会按题字的首字母放进盒子里。\n把鼠标移到刘海，按「屏幕快门」或「自拍」拍第一张。")
                .font(.custom("American Typewriter", size: 12))
                .foregroundStyle(CardInk.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(CardInk.paper))
        .rotationEffect(.degrees(-1.5))
        .shadow(color: .black.opacity(0.24), radius: 1.2, x: 0.6, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 14, x: 4, y: 10)
    }
}
