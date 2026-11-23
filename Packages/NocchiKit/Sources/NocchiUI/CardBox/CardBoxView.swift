import NocchiKit
import SceneKit
import SwiftUI

/// 照片卡片盒（3D）：木头抽屉 + 立着的相片卡 + 桌上的照片堆，叠加首字母检索与「全部放回」。
public struct CardBoxView: View {
    @ObservedObject var model: CardBoxModel
    @StateObject private var stage = CardBoxScene()

    public init(model: CardBoxModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                SceneContainer(stage: stage)
                    .onAppear {
                        stage.setWide(wide)
                        stage.attach(model)
                    }
                    .onChange(of: wide) { _, newValue in
                        stage.setWide(newValue)
                    }

                if model.records.isEmpty {
                    EmptyBoxHint()
                }

                VStack {
                    HStack(alignment: .top) {
                        Spacer()
                        if !model.pulled.isEmpty {
                            PutBackButton { model.putBackAll() }
                        }
                    }
                    Spacer()
                    if wide {
                        LetterStrip(model: model, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(16)

                if !wide {
                    HStack {
                        Spacer()
                        LetterStrip(model: model, vertical: true)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.trailing, 6)
                }
            }
        }
    }
}

#if canImport(UIKit)
private struct SceneContainer: UIViewRepresentable {
    let stage: CardBoxScene

    func makeUIView(context: Context) -> SCNView {
        stage.makeView()
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
#elseif canImport(AppKit)
private struct SceneContainer: NSViewRepresentable {
    let stage: CardBoxScene

    func makeNSView(context: Context) -> SCNView {
        stage.makeView()
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}
}
#endif

private let ink = Color(red: 0.16, green: 0.15, blue: 0.14)
private let terracotta = Color(red: 0.77, green: 0.35, blue: 0.23)

/// A–Z 首字母检索条。点字母：把这一组从抽屉里抽出来（已经在桌上就翻到最上面）。
private struct LetterStrip: View {
    @ObservedObject var model: CardBoxModel
    let vertical: Bool

    var body: some View {
        let available = model.lettersWithCards
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 1)) : AnyLayout(HStackLayout(spacing: 2))
        layout {
            ForEach(IndexLetter.all, id: \.self) { letter in
                let enabled = available.contains(letter)
                let active = model.activeLetter == letter
                Button {
                    model.pull(letter: letter)
                } label: {
                    Text(letter)
                        .font(.system(size: vertical ? 11 : 12, weight: .bold, design: .serif))
                        .frame(width: vertical ? 18 : 18, height: vertical ? 14 : 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(active ? terracotta : Color.clear)
                        )
                        .foregroundStyle(active ? Color.white : ink.opacity(enabled ? 0.85 : 0.22))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
    }
}

private struct PutBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("全部放回", systemImage: "tray.and.arrow.down.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
    }
}

private struct EmptyBoxHint: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("卡片盒还是空的")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Text("拍下的照片会按题字的首字母放进抽屉里。")
                .font(.system(size: 13))
                .opacity(0.7)
        }
        .foregroundStyle(ink)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .offset(y: -120)
    }
}
