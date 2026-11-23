import AppKit
import NocchiKit
import SwiftUI
import UniformTypeIdentifiers

/// 设置：相机柜、胶卷、通用、关于。
struct SettingsView: View {
    var body: some View {
        TabView {
            CameraCabinetTab()
                .tabItem { Label("相机柜", systemImage: "camera") }
            FilmTab()
                .tabItem { Label("胶卷", systemImage: "film") }
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gearshape") }
            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .padding(18)
        .frame(width: 640, height: 560)
    }
}

// MARK: - 相机柜

private struct CameraCabinetTab: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                ForEach(CameraBody.allCases) { camera in
                    BodyCard(camera: camera, selected: model.bodyID == camera.rawValue)
                        .onTapGesture {
                            guard camera.isAvailable else { return }
                            model.bodyID = camera.rawValue
                        }
                }
            }
            .padding(4)
        }
    }
}

private struct BodyCard: View {
    let camera: CameraBody
    let selected: Bool

    private var artName: String? {
        switch camera {
        case .instant: return "CameraInstant"
        case .photoBooth: return "CameraBooth"
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.desk)
                if let artName {
                    Image(artName)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                } else {
                    Image(systemName: camera.symbolName)
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.charcoal.opacity(0.35))
                }
            }
            .frame(height: 120)
            HStack {
                Text(camera.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !camera.isAvailable {
                    Text("即将推出")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }
            Text(camera.tagline)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Palette.terracotta : Color.secondary.opacity(0.2), lineWidth: selected ? 2.5 : 1)
        )
        .opacity(camera.isAvailable ? 1 : 0.6)
    }
}

// MARK: - 胶卷

private struct FilmTab: View {
    @ObservedObject private var model = AppModel.shared
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(model.stocks) { stock in
                        FilmCard(stock: stock, selected: model.stockID == stock.id)
                            .onTapGesture { model.stockID = stock.id }
                            .contextMenu {
                                Button("导出为 .cube…") { export(stock) }
                                if stock.tags.contains("custom") {
                                    Button("删除这卷胶卷", role: .destructive) { model.removeCustomStock(id: stock.id) }
                                }
                            }
                    }
                }
                .padding(4)
            }
            HStack {
                Button("导入 .cube 胶卷…") { importLUT() }
                if let importError {
                    Text(importError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("这一卷：\(model.roll.counterText) · 第 \(model.roll.rollNumber) 卷")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("换新卷") { model.reloadRoll() }
            }
        }
    }

    private func importLUT() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        panel.allowsMultipleSelection = false
        panel.message = "选择一个 .cube LUT 文件，它会变成一卷自定义胶卷。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let result = try Services.library.importLUT(from: url)
            let stock = FilmStock.custom(fromLUT: result.fileName, title: result.lut.title)
            model.addCustomStock(stock)
            model.stockID = stock.id
            importError = nil
        } catch {
            importError = (error as? LocalizedError)?.errorDescription ?? "导入失败：\(error.localizedDescription)"
        }
    }

    private func export(_ stock: FilmStock) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(stock.englishName.isEmpty ? stock.id : stock.englishName).cube"
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = Services.processor.cube(for: stock).cubeText(title: stock.englishName.isEmpty ? stock.name : stock.englishName)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct FilmCard: View {
    let stock: FilmStock
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: stock.swatch.compactMap { RGB(hex: $0) }.map { Color(rgb: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("\(stock.iso)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(4)
            }
            .frame(width: 44, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(stock.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(stock.exposures) 张")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Palette.terracotta : Color.secondary.opacity(0.2), lineWidth: selected ? 2.5 : 1)
        )
    }
}

// MARK: - 通用

private struct GeneralTab: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Form {
            Section("拍摄") {
                Toggle("安静模式（不出声）", isOn: $model.quietMode)
                Toggle("自拍前倒数 3 秒", isOn: $model.selfieCountdown)
                Toggle("接管系统截图（⇧⌘3 / ⇧⌘4 的截图也冲印成相片）", isOn: $model.takeOverScreenshots)
                HStack {
                    Text("显影时长")
                    Slider(value: $model.developSeconds, in: 6...30, step: 1)
                    Text("\(Int(model.developSeconds)) 秒")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                HStack {
                    Text("音量")
                    Slider(value: $model.volume, in: 0...1)
                }
            }
            Section("相纸") {
                TextField("默认题字", text: $model.defaultCaption, prompt: Text(PhotoRecord.defaultCaption))
                Toggle("在白边上印日期", isOn: $model.printDate)
                Picker("新照片放在", selection: $model.defaultLayer) {
                    Text("最上层（浮动）").tag(DeskPlacement.Layer.floating)
                    Text("桌面层（在窗口后面）").tag(DeskPlacement.Layer.desktop)
                }
            }
            Section("快捷键") {
                LabeledContent("屏幕快门", value: "⌃⌥⌘S")
                LabeledContent("自拍", value: "⌃⌥⌘F")
                LabeledContent("大头贴机", value: "⌃⌥⌘B")
            }
            Section("存储") {
                LabeledContent("成片") {
                    Button(Services.library.printsRoot.path) {
                        NSWorkspace.shared.open(Services.library.printsRoot)
                    }
                    .buttonStyle(.link)
                }
                Text("所有照片只存在这台 Mac 上，不上传。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 关于

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text("Nocchi · 刘海冲印店")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")")
                .foregroundStyle(.secondary)
            Text("把刘海当成复古相机的出片口：截图或自拍之后，照片从刘海里吐出来，像真相纸一样慢慢显影。")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Text("机身、图标与纹理为原创设计（由 Codex 生成），胶卷色调由参数配方实时生成，音效为程序合成。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
