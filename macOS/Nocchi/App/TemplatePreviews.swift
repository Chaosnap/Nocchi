import AppKit
import NocchiKit
import SwiftUI

/// 模板预览的缓存：大头贴机的「选相框」和设置里的默认模板用。
///
/// 在后台线程用 `TemplatePreview`（暖灰占位格 + `PhotoComposer`）合成，按「模板 + 规格 + 胶卷 + 宽度 + 题字」缓存。
@MainActor
final class TemplatePreviewStore: ObservableObject {
    struct Request: Hashable {
        var templateID: String
        var format: FilmFormat
        var stockID: String
        var widthPixels: Int
        var caption: String?
        var captionFont: CaptionFont

        /// 用当前的默认题字和题字字体。
        @MainActor
        static func current(templateID: String, format: FilmFormat, stockID: String, widthPixels: Int) -> Request {
            let model = AppModel.shared
            let caption = model.defaultCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            return Request(
                templateID: templateID,
                format: format,
                stockID: stockID,
                widthPixels: max(64, widthPixels),
                caption: caption.isEmpty ? nil : caption,
                captionFont: model.defaultCaptionFont
            )
        }
    }

    @Published private(set) var images: [Request: CGImage] = [:]
    private var pending: Set<Request> = []

    func image(_ request: Request) -> CGImage? {
        images[request]
    }

    /// 按顺序合成还没有的预览（已有的、正在合成的跳过）。
    func prefetch(_ requests: [Request]) async {
        for request in requests {
            if Task.isCancelled { return }
            guard images[request] == nil, !pending.contains(request),
                  let template = TemplateCatalog.template(id: request.templateID) else { continue }
            pending.insert(request)
            let stock = AppModel.shared.stock(id: request.stockID)
            let format = request.format
            let caption = request.caption
            let font = request.captionFont
            let width = request.widthPixels
            let image = await Task.detached(priority: .userInitiated) {
                TemplatePreview.render(template: template, format: format, stock: stock, caption: caption, captionFont: font, widthPixels: width)
            }.value
            pending.remove(request)
            if let image {
                images[request] = image
            }
        }
    }

    func removeAll() {
        images = [:]
        pending = []
    }
}

/// 设置里的一排模板小样：点一下选为默认。
struct TemplateSwatchRow: View {
    let templates: [PrintTemplate]
    @Binding var selection: String
    let format: FilmFormat
    let stock: FilmStock
    @StateObject private var previews = TemplatePreviewStore()
    @ObservedObject private var model = AppModel.shared

    /// 小样高约 96pt，按 2 倍像素合成。
    private var widthPixels: Int {
        max(64, Int((192 * format.layout.aspect).rounded()))
    }

    private func request(_ template: PrintTemplate) -> TemplatePreviewStore.Request {
        .current(templateID: template.id, format: format, stockID: stock.id, widthPixels: widthPixels)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(templates) { template in
                        TemplateSwatch(
                            template: template,
                            image: previews.image(request(template)),
                            selected: selection == template.id
                        ) {
                            selection = template.id
                        }
                        .id(template.id)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
        .task(id: "\(format.rawValue)|\(stock.id)|\(model.defaultCaption)|\(model.defaultCaptionFont.rawValue)") {
            await previews.prefetch(templates.map { request($0) })
        }
    }
}

private struct TemplateSwatch: View {
    let template: PrintTemplate
    let image: CGImage?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Palette.paperDeep.opacity(0.75))
                    if let image {
                        Image(decorative: image, scale: 2)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .shadow(color: .black.opacity(0.28), radius: 0.8, y: 0.5)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            .padding(8)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(width: 96, height: 112)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(selected ? Palette.terracotta : Palette.hairline, lineWidth: selected ? 2 : 0.6)
                )
                Text(template.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Palette.terracotta : Color.primary)
                    .lineLimit(1)
            }
            .frame(width: 100)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(template.note)
    }
}
