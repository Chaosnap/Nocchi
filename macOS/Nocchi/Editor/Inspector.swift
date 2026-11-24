import AppKit
import NocchiKit
import SwiftUI
import UniformTypeIdentifiers

/// 右边的检查器（纸色）：贴纸 / 模板 / 文字 / 分享。
struct Inspector: View {
    @ObservedObject var session: DecorateSession

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabs(tab: $session.tab)
                .padding(.top, 40)
                .padding(.horizontal, 14)
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.6)
            ScrollView {
                Group {
                    switch session.tab {
                    case .stickers: StickersTab(session: session)
                    case .templates: TemplatesTab(session: session)
                    case .text: TextTab(session: session)
                    case .share: ShareTab(session: session)
                    }
                }
                .padding(16)
            }
        }
        .background(Palette.paper)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.35)).frame(width: 1)
        }
        .environment(\.colorScheme, .light)
        .tint(Palette.terracotta)
    }
}

private struct InspectorTabs: View {
    @Binding var tab: DecorateSession.Tab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DecorateSession.Tab.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { tab = item }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(tab == item ? Palette.terracotta : Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(tab == item ? Palette.terracotta : Color.clear)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 小节标题（宋体）。
private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RetroFont.serif(13, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 胶囊按钮（分类、建议标签、摆法）。
private struct Pill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(selected ? Palette.terracotta : Palette.paperDeep))
                .overlay(Capsule().stroke(selected ? Color.clear : Palette.hairline, lineWidth: 0.6))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 贴纸

private struct StickersTab: View {
    @ObservedObject var session: DecorateSession
    @ObservedObject private var shelf = StickerShelf.shared
    /// nil = 我的贴纸。
    @State private var category: StickerCategory? = .badge
    @State private var dropTargeted = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init(session: DecorateSession) {
        self.session = session
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let id = session.selectedSticker, let placement = session.sticker(id), let kind = StickerArt.kind(forID: placement.kindID) {
                SelectedStickerPanel(session: session, placement: placement, kind: kind)
            }
            FlowLayout(spacing: 5) {
                Pill(title: "我的", selected: category == nil) { category = nil }
                ForEach(StickerCategory.allCases) { item in
                    Pill(title: item.displayName, selected: category == item) { category = item }
                }
            }
            if let category {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(StickerCatalog.kinds(in: category)) { kind in
                        StickerTile(kind: kind) { session.addSticker(kind) }
                    }
                }
            } else {
                mine
            }
            Text("点一下贴到相纸中央；拖动移动，右下角手柄缩放旋转，⌫ 删除。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkSoft)
        }
    }

    /// 我的贴纸：导入（点或拖图片进来）+ 自己的贴纸（右键重命名、模切边、排序、删掉）。
    private var mine: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 10) {
                Button {
                    shelf.importWithPanel()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text("导入图片")
                            .font(RetroFont.typewriter(10))
                    }
                    .foregroundStyle(Palette.terracotta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Palette.terracotta.opacity(dropTargeted ? 0.9 : 0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("选几张图片做成贴纸，也可以直接把图片拖进来")
                ForEach(shelf.stickers) { sticker in
                    StickerTile(kind: sticker.kind) { session.addSticker(sticker.kind) }
                        .contextMenu {
                            Button("重命名…") { shelf.rename(sticker) }
                            Button(sticker.dieCut ? "去掉白色模切边" : "加上白色模切边") { shelf.toggleDieCut(sticker) }
                            Button("往前挪") { shelf.move(sticker, by: -1) }
                            Button("往后挪") { shelf.move(sticker, by: 1) }
                            Divider()
                            Button("从贴纸库删掉", role: .destructive) { shelf.remove(sticker) }
                        }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.terracotta.opacity(dropTargeted ? 0.08 : 0))
            )
            .dropDestination(for: URL.self) { urls, _ in
                shelf.importFiles(urls)
                return true
            } isTargeted: { targeted in
                dropTargeted = targeted
            }
            if let message = shelf.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            } else if shelf.stickers.isEmpty {
                Text("把喜欢的图标、手账素材、小照片拖进来，就成了自己的贴纸；右键可以重命名、换模切边、排序。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StickerTile: View {
    let kind: StickerKind
    let action: () -> Void
    @State private var hovering = false

    init(kind: StickerKind, action: @escaping () -> Void) {
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let image = StickerImageCache.shared.image(kind.id, width: 70, seed: 3) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 58)
                Text(kind.name)
                    .font(RetroFont.typewriter(10))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: 0xFBF8F1)))
            .shadow(color: .black.opacity(hovering ? 0.22 : 0.12), radius: hovering ? 5 : 2, y: hovering ? 3 : 1)
            .scaleEffect(hovering ? 1.04 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { hovering = inside }
        }
        .help(kind.name)
    }
}

/// 选中的贴纸：能写字的显示文字框，能换色的显示色点，以及翻转 / 置顶 / 删除。
private struct SelectedStickerPanel: View {
    @ObservedObject var session: DecorateSession
    let placement: StickerPlacement
    let kind: StickerKind

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "选中：\(kind.name)")
            if kind.acceptsText {
                TextField("贴纸上的字", text: Binding(
                    get: { placement.text ?? "" },
                    set: { value in session.updateSticker(placement.id) { $0.text = value } }
                ))
                .textFieldStyle(.roundedBorder)
            }
            if kind.tintable {
                HStack(spacing: 6) {
                    ForEach(DecorateSession.paints) { paint in
                        Button {
                            session.editSticker(placement.id) { $0.tint = paint.hex }
                        } label: {
                            Circle()
                                .fill(Color(rgbHex: paint.hex))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Palette.ink.opacity(placement.tint == paint.hex ? 0.9 : 0.2), lineWidth: placement.tint == paint.hex ? 2 : 0.6))
                        }
                        .buttonStyle(.plain)
                        .help(paint.name)
                    }
                }
            }
            HStack(spacing: 8) {
                Pill(title: "翻转", selected: false) { session.editSticker(placement.id) { $0.flipped.toggle() } }
                Pill(title: "置顶", selected: false) { session.bringSelectedToFront() }
                Pill(title: "删除", selected: false) { session.deleteSelectedSticker() }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.paperDeep.opacity(0.7)))
    }
}

// MARK: - 模板

private struct TemplatesTab: View {
    @ObservedObject var session: DecorateSession
    @State private var thumbnails: [String: CGImage] = [:]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let templates = TemplateCatalog.templates(for: session.record.format)
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "相纸模板 · \(session.record.format.displayName)")
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(templates) { template in
                    TemplateTile(
                        template: template,
                        image: thumbnails[template.id],
                        selected: session.record.effectiveTemplateID == template.id
                    ) {
                        session.edit { $0.templateID = template.id }
                    }
                }
            }
        }
        .task(id: "\(session.record.format)#\(session.record.caption ?? "")#\(session.record.captionFont)") {
            await renderThumbnails(templates)
        }
    }

    /// 用这张照片自己的底片逐个合成缩略图（后台线程）。
    private func renderThumbnails(_ templates: [PrintTemplate]) async {
        var base = session.record
        base.stickers = []
        base.texts = []
        base.strokes = []
        let paper = session.stockPaper
        let images = session.images
        for template in templates {
            if Task.isCancelled { return }
            var record = base
            record.templateID = template.id
            let probe = record
            let image: CGImage? = await Task.detached(priority: .utility) {
                PhotoComposer.render(PrintSpec(record: probe, stockPaper: paper, images: images, widthPixels: 320))
            }.value
            if let image {
                thumbnails[template.id] = image
            }
        }
    }
}

private struct TemplateTile: View {
    let template: PrintTemplate
    let image: CGImage?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.paperDeep)
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .padding(8)
                            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(selected ? Palette.terracotta : Palette.hairline, lineWidth: selected ? 2 : 0.6)
                )
                Text(template.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Palette.terracotta : Palette.ink)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(template.note)
    }
}

// MARK: - 文字

private struct TextTab: View {
    @ObservedObject var session: DecorateSession
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "照片上的文字")
                if let id = session.selectedText, let placement = session.text(id) {
                    TextBoxEditor(session: session, placement: placement)
                } else {
                    Text("在照片上任何地方加一段字，字体、大小、颜色都能换。也可以选左边的「T」，在照片上点一下。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Pill(title: "＋ 加一段字", selected: session.selectedText == nil) { session.addText() }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "题字 / 心情")
                TextField("写一句题字…", text: binding(\.caption), axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Picker("字体", selection: Binding(
                    get: { session.record.captionFont },
                    set: { value in session.edit { $0.captionFont = value } }
                )) {
                    ForEach(CaptionFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "日期")
                DatePicker("拍摄时间", selection: Binding(
                    get: { session.record.displayDate },
                    set: { value in session.edit { $0.takenAt = value } }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                Toggle("在相纸上印日期", isOn: Binding(
                    get: { session.record.showsDate },
                    set: { value in session.edit { $0.showsDate = value } }
                ))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "地点")
                TextField("例如：上海 · 武康路", text: binding(\.location))
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "标签")
                TagFlow(tags: StickerCatalog.suggestedTags, selected: Set(session.record.tags)) { tag in
                    toggleTag(tag)
                }
                let custom = session.record.tags.filter { !StickerCatalog.suggestedTags.contains($0) }
                if !custom.isEmpty {
                    TagFlow(tags: custom, selected: Set(custom)) { tag in
                        toggleTag(tag)
                    }
                }
                TextField("自己写一个标签，回车添加", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let tag = PhotoRecord.normalizedTag(newTag)
                        if !tag.isEmpty, !session.record.tags.contains(tag) {
                            session.edit { $0.tags.append(tag) }
                        }
                        newTag = ""
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: "印在相纸上")
                Toggle("印标签", isOn: flag(\.showsTags))
                Toggle("印地点", isOn: flag(\.showsLocation))
                Toggle("标签配小贴纸（#阳光 → 太阳徽章）", isOn: flag(\.showsTagStickers))
            }
        }
        .toggleStyle(.checkbox)
    }

    private func toggleTag(_ tag: String) {
        session.edit { record in
            if let index = record.tags.firstIndex(of: tag) {
                record.tags.remove(at: index)
            } else {
                record.tags.append(tag)
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<PhotoRecord, String?>) -> Binding<String> {
        Binding(
            get: { session.record[keyPath: keyPath] ?? "" },
            set: { value in
                session.edit { $0[keyPath: keyPath] = value.isEmpty ? nil : value }
            }
        )
    }

    private func flag(_ keyPath: WritableKeyPath<PhotoRecord, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.record[keyPath: keyPath] },
            set: { value in session.edit { $0[keyPath: keyPath] = value } }
        )
    }
}

/// 标签胶囊，按宽度自动换行。
private struct TagFlow: View {
    let tags: [String]
    let selected: Set<String>
    let action: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Pill(title: "#\(tag)", selected: selected.contains(tag)) { action(tag) }
            }
        }
    }
}

/// 简单的换行排布。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        return CGSize(width: width, height: rows(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = rows(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], height: CGFloat) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, y + rowHeight)
    }
}

// MARK: - 分享

private struct ShareTab: View {
    @ObservedObject var session: DecorateSession
    @State private var background: PosterBackground = .linen
    @State private var arrangement: PosterArrangement = .centered
    @State private var signature = true
    @State private var poster: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Palette.paperDeep)
                if let poster {
                    Image(decorative: poster, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            SectionTitle(text: "背景")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(PosterBackground.allCases) { item in
                    Button {
                        background = item
                    } label: {
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.swatch)
                                .frame(height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(background == item ? Palette.terracotta : Palette.hairline, lineWidth: background == item ? 2 : 0.6)
                                )
                            Text(item.title)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            SectionTitle(text: "摆法")
            HStack(spacing: 6) {
                ForEach(PosterArrangement.allCases) { item in
                    Pill(title: item.title, selected: arrangement == item) { arrangement = item }
                }
            }
            Toggle("右下角印「Nocchi · 日期」", isOn: $signature)
                .toggleStyle(.checkbox)

            HStack(spacing: 8) {
                Pill(title: "导出图片…", selected: true) { export() }
                Pill(title: "拷贝", selected: false) { copy() }
                Pill(title: "分享…", selected: false) { share() }
            }
        }
        .task(id: "\(background.rawValue)#\(arrangement.rawValue)#\(signature)#\(session.record.hashValue)") {
            poster = await makePoster()
        }
    }

    private func makePoster() async -> CGImage? {
        let record = session.record
        let paper = session.stockPaper
        let images = session.images
        let background = self.background
        let arrangement = self.arrangement
        let line = signature ? "Nocchi · \(record.dateText)" : nil
        let textures = PosterTextures.load(for: background)
        return await Task.detached(priority: .userInitiated) {
            guard let print = PhotoComposer.render(PrintSpec(record: record, stockPaper: paper, images: images, widthPixels: 900)) else { return nil }
            return PosterRenderer.render(print: print, background: background, arrangement: arrangement, signature: line, texture: textures)
        }.value
    }

    private var fileStem: String {
        "Nocchi-\(session.record.dateText.replacingOccurrences(of: "/", with: "-"))"
    }

    private func export() {
        guard let poster else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.nameFieldStringValue = fileStem + ".jpg"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let png = url.pathExtension.lowercased() == "png"
        let rep = NSBitmapImageRep(cgImage: poster)
        let data = png ? rep.representation(using: .png, properties: [:]) : rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        try? data?.write(to: url)
    }

    private func copy() {
        guard let poster else { return }
        let image = NSImage(cgImage: poster, size: NSSize(width: poster.width, height: poster.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        SoundPlayer.shared.play(.cardSlide)
    }

    private func share() {
        guard let poster, let view = NSApp.keyWindow?.contentView else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileStem + ".jpg")
        let rep = NSBitmapImageRep(cgImage: poster)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]), (try? data.write(to: url)) != nil else { return }
        let picker = NSSharingServicePicker(items: [url])
        let anchor = NSRect(x: view.bounds.maxX - 170, y: 40, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: view, preferredEdge: .maxY)
    }
}

// MARK: - 文字框编辑

/// 选中的文字框：内容、字体、大小、颜色、对齐、样式、粗体 / 斜体、字距。
private struct TextBoxEditor: View {
    @ObservedObject var session: DecorateSession
    let placement: TextPlacement
    @FocusState private var editing: Bool
    @State private var showsFonts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: Binding(
                get: { placement.text },
                set: { value in session.updateText(placement.id) { $0.text = value } }
            ))
            .font(.system(size: 13))
            .foregroundStyle(Palette.ink)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(editing ? Palette.terracotta.opacity(0.6) : Palette.hairline, lineWidth: editing ? 1.2 : 0.6))
            .focused($editing)
            .onChange(of: editing) { _, now in
                if now { session.checkpoint() }
            }
            .onChange(of: session.textFocusRequest) { _, _ in editing = true }
            .onAppear {
                if session.textFocusRequest > 0 { editing = true }
            }

            HStack(spacing: 8) {
                Button {
                    showsFonts.toggle()
                } label: {
                    HStack {
                        Text(placement.fontFamily)
                            .font(.custom(placement.fontFamily, size: 14))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.75)))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Palette.hairline, lineWidth: 0.6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsFonts, arrowEdge: .leading) {
                    FontPicker(selection: placement.fontFamily) { family in
                        session.editText(placement.id) { $0.fontFamily = family }
                    }
                    .environment(\.colorScheme, .light)
                    .scrollIndicators(.never)
                }
                Toggle("粗", isOn: Binding(get: { placement.bold }, set: { value in session.editText(placement.id) { $0.bold = value } }))
                Toggle("斜", isOn: Binding(get: { placement.italic }, set: { value in session.editText(placement.id) { $0.italic = value } }))
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 8) {
                Text("大小")
                    .font(RetroFont.typewriter(11))
                    .foregroundStyle(Palette.inkSoft)
                Slider(
                    value: Binding(get: { placement.size }, set: { value in session.updateText(placement.id) { $0.size = value } }),
                    in: 0.025...0.25,
                    onEditingChanged: { editing in if editing { session.checkpoint() } }
                )
            }
            HStack(spacing: 8) {
                Text("字距")
                    .font(RetroFont.typewriter(11))
                    .foregroundStyle(Palette.inkSoft)
                Slider(
                    value: Binding(get: { placement.tracking }, set: { value in session.updateText(placement.id) { $0.tracking = value } }),
                    in: -0.05...0.4,
                    onEditingChanged: { editing in if editing { session.checkpoint() } }
                )
            }

            HStack(spacing: 6) {
                ForEach(DecorateSession.paints + [DecorateSession.Paint(name: "纸白", hex: "#FFFFFF")]) { paint in
                    Button {
                        session.editText(placement.id) { $0.color = paint.hex }
                    } label: {
                        Circle()
                            .fill(Color(rgbHex: paint.hex))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Palette.ink.opacity(placement.color == paint.hex ? 0.9 : 0.2), lineWidth: placement.color == paint.hex ? 2 : 0.6))
                    }
                    .buttonStyle(.plain)
                    .help(paint.name)
                }
            }

            Picker("对齐", selection: Binding(get: { placement.alignment }, set: { value in session.editText(placement.id) { $0.alignment = value } })) {
                Text("左").tag(-1)
                Text("中").tag(0)
                Text("右").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 6) {
                ForEach(TextPlacement.Style.allCases) { style in
                    Pill(title: style.displayName, selected: placement.style == style) {
                        session.editText(placement.id) { $0.style = style }
                    }
                }
                Spacer(minLength: 0)
                Button {
                    session.deleteSelectedText()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.printRed)
                }
                .buttonStyle(.plain)
                .help("删掉这段字")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.paperDeep.opacity(0.7)))
    }
}

/// 字体选择：搜索框 + 我导入的 / 推荐 / 全部字体（每一行用它自己的字体显示）+「导入字体…」。
private struct FontPicker: View {
    let selection: String
    let choose: (String) -> Void
    @State private var query = ""
    @State private var imported: [String] = Services.fonts.families
    @State private var families: [String] = FontBook.sortedFamilies
    @State private var message: String?

    private static let recommendedNames = [
        "Didot", "Bodoni 72", "Baskerville", "Big Caslon", "Hoefler Text", "Cochin", "American Typewriter",
        "Courier New", "Futura", "Gill Sans", "Avenir Next Condensed", "Bradley Hand", "Snell Roundhand",
        "Savoye LET", "Songti SC", "Kaiti SC", "Hiragino Mincho ProN", "PingFang SC"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("搜索字体", text: $query)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let filter = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    let recommended = Self.recommendedNames.filter { FontBook.isInstalled($0) }
                    if !imported.isEmpty {
                        header("我导入的")
                        ForEach(matching(imported, filter), id: \.self) { name in
                            row(name)
                                .contextMenu {
                                    Button("删除这个字体", role: .destructive) {
                                        Services.fonts.remove(family: name)
                                        imported = Services.fonts.families
                                        families = FontBook.sortedFamilies
                                    }
                                }
                        }
                    }
                    if filter.isEmpty {
                        header("推荐")
                        ForEach(recommended, id: \.self) { row($0) }
                    }
                    header(filter.isEmpty ? "全部字体" : "搜索结果")
                    ForEach(matching(families, filter), id: \.self) { row($0) }
                }
            }
            .frame(height: 300)
            HStack {
                Button("导入字体…") { importFonts() }
                if let message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(Palette.paper)
    }

    private func matching(_ names: [String], _ filter: String) -> [String] {
        guard !filter.isEmpty else { return names }
        return names.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(RetroFont.typewriter(10.5))
            .tracking(1)
            .foregroundStyle(Palette.inkSoft)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func row(_ name: String) -> some View {
        Button {
            choose(name)
        } label: {
            HStack {
                Text(name)
                    .font(.custom(name, size: 15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if name == selection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.terracotta)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 导入 .ttf / .otf / .ttc：复制进照片库的 fonts/，在本进程注册，选中第一个家族。
    private func importFonts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.font]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "选几个字体文件（.ttf / .otf / .ttc），导入后只在 Nocchi 里用"
        guard panel.runModal() == .OK else { return }
        var added: [String] = []
        var failed = 0
        for url in panel.urls {
            if let names = try? Services.fonts.importFont(from: url) {
                added.append(contentsOf: names)
            } else {
                failed += 1
            }
        }
        imported = Services.fonts.families
        families = FontBook.sortedFamilies
        if let first = added.first {
            choose(first)
        }
        message = failed > 0 ? "有 \(failed) 个文件读不出字体" : (added.isEmpty ? nil : "导入了 \(added.count) 个字体")
    }
}
