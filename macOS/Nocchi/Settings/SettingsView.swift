import AppKit
import NocchiKit
import SwiftUI
import UniformTypeIdentifiers

/// 设置：相机柜、胶卷、相纸、摄像头、通用、关于。
struct SettingsView: View {
    var body: some View {
        TabView {
            CameraCabinetTab()
                .tabItem { Label("相机柜", systemImage: "camera") }
            FilmTab()
                .tabItem { Label("胶卷", systemImage: "film") }
            PrintTab()
                .tabItem { Label("相纸", systemImage: "photo.on.rectangle.angled") }
            CameraTab()
                .tabItem { Label("摄像头", systemImage: "web.camera") }
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
            FilmCanisterImage(stock: stock, size: 58)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(stock.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("ISO \(stock.iso) · \(stock.exposures) 张 · \(stock.family.displayName)")
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
            Section("程序") {
                Toggle("启动时打开相册（卡片盒）", isOn: $model.openAlbumOnLaunch)
                Toggle("在程序坞显示图标", isOn: $model.showsDockIcon)
                Text("关掉后 Nocchi 只住在菜单栏和刘海里（没有程序坞图标和主菜单）。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
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

// MARK: - 相纸与装饰

/// 相纸：即显相纸与默认模板、大头贴的版式 / 相框 / 黑白、题字、拍完之后。
private struct PrintTab: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Form {
            Section("即显相机（自拍、屏幕快门、冲印照片）") {
                PaperChooser(selection: $model.instantFormat)
                VStack(alignment: .leading, spacing: 6) {
                    Text("默认模板")
                    TemplateSwatchRow(
                        templates: TemplateCatalog.templates(for: model.instantFormat),
                        selection: $model.defaultInstantTemplateID,
                        format: model.instantFormat,
                        stock: model.currentStock
                    )
                    if let note = instantTemplateNote {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("大头贴机") {
                Picker("版式", selection: $model.boothFormat) {
                    ForEach(FilmFormat.boothChoices) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("拍黑白", isOn: $model.boothMonochrome)
                VStack(alignment: .leading, spacing: 6) {
                    Text("默认相框")
                    TemplateSwatchRow(
                        templates: TemplateCatalog.boothTemplates(for: model.boothFormat),
                        selection: $model.defaultBoothTemplateID,
                        format: model.boothFormat,
                        stock: model.boothStock(monochrome: model.boothMonochrome)
                    )
                    Text("拉上布帘后还可以再挑；在大头贴机里换了相框、版式或黑白，下次就从换好的开始。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Section("题字") {
                TextField("默认题字", text: $model.defaultCaption, prompt: Text(PhotoRecord.defaultCaption))
                Picker("题字字体", selection: $model.defaultCaptionFont) {
                    ForEach(CaptionFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("在白边上印日期", isOn: $model.printDate)
            }
            Section("拍完之后") {
                Toggle("显影完成后自动打开装饰台", isOn: $model.autoOpenDecorate)
                Text("相片一显影好就打开装饰台，可以马上贴贴纸、换模板、写字。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("新照片放在", selection: $model.defaultLayer) {
                    Text("最上层（浮动）").tag(DeskPlacement.Layer.floating)
                    Text("桌面层（在窗口后面）").tag(DeskPlacement.Layer.desktop)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// 默认模板不适用于当前相纸时提示一句。
    private var instantTemplateNote: String? {
        guard let chosen = TemplateCatalog.template(id: model.defaultInstantTemplateID),
              !chosen.formats.contains(model.instantFormat) else { return nil }
        return "「\(chosen.name)」不适用于\(model.instantFormat.displayName)，这种相纸会用「经典」。"
    }
}

/// 即显相纸的选择：按真实比例画出四种相纸。
private struct PaperChooser: View {
    @Binding var selection: FilmFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即显相机用的相纸")
            HStack(spacing: 10) {
                ForEach(FilmFormat.instantChoices) { format in
                    Button {
                        selection = format
                    } label: {
                        VStack(spacing: 6) {
                            PaperSilhouette(format: format, paperColor: Palette.ivoryLight)
                                .frame(width: 54, height: 54)
                            Text(format.displayName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selection == format ? Palette.terracotta : Color.secondary.opacity(0.2), lineWidth: selection == format ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(format.note)
                }
            }
            Text(selection.note)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 摄像头

/// 摄像头：实时预览 + 设备列表（内建、外接 / 虚拟、iPhone）+ 镜像开关。
private struct CameraTab: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var camera = CameraService.shared
    @State private var ownsPreview = false
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            preview
            ScrollView {
                VStack(spacing: 6) {
                    CameraRow(title: "系统默认", detail: "跟随 macOS 的默认摄像头", symbol: "camera", badge: nil, selected: model.cameraDeviceID == nil) {
                        model.cameraDeviceID = nil
                    }
                    ForEach(camera.devices) { device in
                        CameraRow(title: device.name, detail: nil, symbol: device.kind.symbolName, badge: device.kind.badge, selected: model.cameraDeviceID == device.id) {
                            model.cameraDeviceID = device.id
                        }
                    }
                }
                .padding(2)
            }
            .frame(maxHeight: 170)
            Toggle("自拍画面镜像（像照镜子一样）", isOn: $model.mirrorSelfie)
            Text("OBS、Camo 等以「摄像头扩展」形式安装的虚拟摄像头会出现在「外接 / 虚拟」里。正在用的摄像头拔掉时，Nocchi 会自动换回默认摄像头。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            camera.refreshDevices()
            startPreview()
        }
        .onDisappear {
            stopPreview()
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black)
            if camera.isRunning {
                CameraPreview(session: camera.session, mirrored: model.mirrorSelfie, isRunning: camera.isRunning)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if let name = camera.activeDeviceName {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .foregroundStyle(.white)
                        .padding(10)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: denied ? "video.slash" : "video")
                        .font(.system(size: 22))
                    Text(denied ? "没有摄像头权限（系统设置 → 隐私与安全性 → 摄像头）" : "正在打开摄像头…")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 200)
    }

    private func startPreview() {
        guard !camera.isRunning else { return }
        Task {
            guard await CameraAccess.ensure() else {
                denied = true
                return
            }
            do {
                try await camera.start()
                ownsPreview = true
            } catch {
                denied = true
            }
        }
    }

    private func stopPreview() {
        guard ownsPreview else { return }
        ownsPreview = false
        // 自拍或大头贴机正在用摄像头时不要关。
        if NotchController.shared.mode == .selfie || PhotoBoothController.shared.isActive { return }
        camera.stop()
    }
}

private struct CameraRow: View {
    let title: String
    let detail: String?
    let symbol: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .frame(width: 24)
                    .foregroundStyle(Palette.ink.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Palette.terracotta : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Palette.terracotta.opacity(0.7) : Color.secondary.opacity(0.15), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
