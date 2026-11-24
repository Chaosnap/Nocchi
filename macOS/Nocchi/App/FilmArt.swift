import AppKit
import NocchiKit
import SwiftUI

/// 胶卷与相纸的小图：Blender 渲染的胶卷罐 / 相纸盒（`FilmCanister-<id>`），没有图时用 SwiftUI 画一个复古的替身。
enum FilmArt {
    /// 资源名：内置胶卷 `FilmCanister-<id>`，自定义 LUT 胶卷 `FilmCanister-custom`。
    static func canisterName(for stock: FilmStock) -> String {
        stock.family == .custom ? "FilmCanister-custom" : "FilmCanister-\(stock.id)"
    }

    @MainActor
    static func canister(for stock: FilmStock) -> NSImage? {
        NSImage(named: canisterName(for: stock))
    }
}

/// 一卷胶卷的小图（胶卷罐或相纸盒）。
struct FilmCanisterImage: View {
    let stock: FilmStock
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image = FilmArt.canister(for: stock) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if stock.family == .instant || stock.family == .booth {
                InstantPackFallback(stock: stock)
            } else {
                CanisterFallback(stock: stock)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(stock.name))
    }
}

/// 胶卷罐替身：铝盖 + 印着色带和 ISO 的标签 + 黑色绒口和一小截片头。
private struct CanisterFallback: View {
    let stock: FilmStock

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let bodyW = s * 0.46
            let bodyH = s * 0.56
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: bodyW * 1.15, height: s * 0.07)
                    .blur(radius: s * 0.025)
                    .offset(x: s * 0.03, y: bodyH / 2 + s * 0.07)
                // 片头
                RoundedRectangle(cornerRadius: s * 0.012)
                    .fill(Color(red: 0.36, green: 0.22, blue: 0.12))
                    .frame(width: s * 0.2, height: bodyH * 0.5)
                    .offset(x: bodyW / 2 + s * 0.06, y: s * 0.03)
                // 罐身
                ZStack {
                    RoundedRectangle(cornerRadius: s * 0.03)
                        .fill(LinearGradient(colors: [Palette.ivoryShade, Palette.ivoryLight, Palette.ivory, Palette.ivoryShade.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                    VStack(spacing: s * 0.012) {
                        bands(width: bodyW)
                        Text("\(stock.iso)")
                            .font(.custom("Futura-CondensedExtraBold", size: s * 0.14))
                            .foregroundStyle(Palette.ink)
                        Text("NOCCHI")
                            .font(.custom("American Typewriter", size: s * 0.055).weight(.semibold))
                            .foregroundStyle(Palette.ink.opacity(0.75))
                            .tracking(s * 0.008)
                    }
                    // 圆柱高光
                    LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.35), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: bodyW * 0.18)
                        .offset(x: -bodyW * 0.2)
                        .blendMode(.screen)
                }
                .frame(width: bodyW, height: bodyH)
                .clipShape(RoundedRectangle(cornerRadius: s * 0.03))
                // 上下铝盖
                metalCap(width: bodyW * 1.06, height: s * 0.07)
                    .offset(y: -bodyH / 2)
                metalCap(width: bodyW * 1.06, height: s * 0.07)
                    .offset(y: bodyH / 2)
                // 轴芯
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.25), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                    .frame(width: bodyW * 0.36, height: s * 0.07)
                    .offset(y: -bodyH / 2 - s * 0.06)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func bands(width: CGFloat) -> some View {
        let colors = stock.swatch.compactMap { RGB(hex: $0) }.map { Color(rgb: $0) }
        return VStack(spacing: 0) {
            ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { item in
                Rectangle()
                    .fill(item.element)
                    .frame(width: width, height: width * 0.09)
            }
        }
    }

    private func metalCap(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.35)
            .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.92), Color(white: 0.7), Color(white: 0.45)], startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: height * 0.35).stroke(Color.black.opacity(0.25), lineWidth: 0.5))
    }
}

/// 相纸盒替身：一盒即显相纸，最上面一张露出厚底边。
private struct InstantPackFallback: View {
    let stock: FilmStock

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let aspect = (stock.recommendedFormat ?? .instantSquare).layout.aspect
            let h = s * 0.66
            let w = min(h * aspect, s * 0.8)
            let colors = stock.swatch.compactMap { RGB(hex: $0) }.map { Color(rgb: $0) }
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: w * 1.1, height: s * 0.07)
                    .blur(radius: s * 0.025)
                    .offset(x: s * 0.02, y: h / 2 + s * 0.05)
                RoundedRectangle(cornerRadius: s * 0.03)
                    .fill(LinearGradient(colors: [Palette.charcoal, Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h)
                // 露出来的一张相纸
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(LinearGradient(colors: colors.isEmpty ? [Palette.ivoryShade] : colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(s * 0.035)
                        .frame(height: h * 0.62)
                    Spacer(minLength: 0)
                }
                .frame(width: w * 0.84, height: h * 0.8)
                .background(Palette.ivoryLight)
                .clipShape(RoundedRectangle(cornerRadius: s * 0.012))
                .offset(y: -h * 0.04)
                Text("\(stock.iso)")
                    .font(.custom("Futura-CondensedExtraBold", size: s * 0.1))
                    .foregroundStyle(Palette.ivory)
                    .offset(y: h / 2 - s * 0.07)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
