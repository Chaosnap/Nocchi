import NocchiKit
import NocchiUI
import SwiftUI

/// 桌面上的一张相片：精细纸面（NocchiUI.PrintSurface）+ 出片遮罩 + 倾斜 + 三层阴影。
struct InstantPhotoView: View {
    @ObservedObject var model: PhotoViewModel

    var body: some View {
        let pad = PhotoViewModel.padding
        let size = model.paperSize
        let window = model.windowSize
        PrintSurface(
            record: model.record,
            images: model.displayImages,
            visuals: model.record.negatives.indices.map { model.visual(at: $0) },
            paper: model.paper,
            width: model.paperWidth,
            liveStroke: model.liveStroke,
            sheen: model.sheen
        )
        .frame(width: size.width, height: size.height)
        .scaleEffect(model.lifted ? 1.035 : 1)
        .rotationEffect(.degrees(model.tilt))
        // 三层阴影：贴着桌面的接触阴影、中距离柔影、大范围环境影；拿起来时更远更散。
        .shadow(color: .black.opacity(model.lifted ? 0.10 : 0.28), radius: model.lifted ? 2 : 0.7, x: 0, y: model.lifted ? 2 : 0.5)
        .shadow(color: .black.opacity(model.lifted ? 0.16 : 0.14), radius: model.lifted ? 7 : 3.5, x: 0, y: model.lifted ? 6 : 2.5)
        .shadow(color: .black.opacity(model.lifted ? 0.20 : 0.10), radius: model.lifted ? 17 : 12, x: 0, y: model.lifted ? 13 : 8)
        .offset(y: -size.height * (1 - model.ejectProgress))
        .frame(width: window.width, height: window.height)
        .mask(alignment: .bottom) {
            Rectangle()
                .frame(width: window.width, height: model.masking ? window.height - pad : window.height)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: model.lifted)
    }
}
