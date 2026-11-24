import AppKit
import NocchiKit
import SwiftUI

/// 设置 → 通用 → 存储：成片放在哪里。可以换到别的文件夹（外接盘、网盘同步文件夹……），
/// 已有的成片一起搬过去（`PhotoLibrary.relocatePrints(to:)`，在后台搬，界面上转圈）；照片记录和底片留在「应用程序支持」里。
struct StorageSection: View {
    @State private var path = Services.library.printsRoot.path
    @State private var isCustom = PrintsLocation.customRoot != nil
    @State private var moving = false
    @State private var message: String?

    var body: some View {
        Section("存储") {
            LabeledContent("成片") {
                Button(path) {
                    NSWorkspace.shared.open(Services.library.printsRoot)
                }
                .buttonStyle(.link)
                .lineLimit(1)
                .truncationMode(.middle)
                .help("在访达中打开")
            }
            HStack(spacing: 8) {
                if moving {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在搬成片…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("在访达中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([Services.library.printsRoot])
                }
                if isCustom {
                    Button("恢复默认") { move(to: PrintsLocation.defaultRoot) }
                }
                Button("更改…") { choose() }
            }
            .disabled(moving)
            if let unavailable = PrintsLocation.unavailableRoot {
                Text("找不到「\(unavailable.path)」（外接盘没插上？），这次先存在默认位置。插上后重新打开 Nocchi 就会用回那里。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
            }
            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text("所有照片只存在这台 Mac 上，不上传。换位置时，已有的成片会一起搬过去；照片记录和底片留在「应用程序支持」里。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "用这个文件夹")
        panel.message = String(localized: "选一个文件夹放成片（之后冲印的照片也放在这里）")
        panel.directoryURL = Services.library.printsRoot.deletingLastPathComponent()
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        move(to: PrintsLocation.printsFolder(forChosen: chosen))
    }

    private func move(to destination: URL) {
        let library = Services.library
        guard destination.standardizedFileURL.path != library.printsRoot.standardizedFileURL.path else { return }
        let count = library.printFileCount()
        let alert = NSAlert()
        alert.messageText = String(localized: "把成片放到这里？")
        alert.informativeText = count > 0
            ? String(localized: "「\(destination.path)」\n\n已有的 \(count) 个成片文件会一起搬过去，之后冲印的照片也放在这里。")
            : String(localized: "「\(destination.path)」\n\n之后冲印的照片都放在这里。")
        alert.addButton(withTitle: count > 0 ? String(localized: "搬过去") : String(localized: "就用这里"))
        alert.addButton(withTitle: String(localized: "取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        moving = true
        message = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try library.relocatePrints(to: destination) }
            }.value
            moving = false
            switch result {
            case .success(let outcome):
                PrintsLocation.remember(destination)
                path = library.printsRoot.path
                isCustom = PrintsLocation.customRoot != nil
                if !outcome.skipped.isEmpty {
                    message = String(localized: "搬好了 \(outcome.moved) 个文件；有 \(outcome.skipped.count) 个在新位置已经有同名文件，没有覆盖，留在了原处。")
                } else if outcome.moved > 0 {
                    message = String(localized: "搬好了：\(outcome.moved) 个文件。")
                }
            case .failure(let error):
                message = Self.describe(error)
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error as? PhotoLibrary.RelocationError {
        case .nested:
            return String(localized: "新位置不能在现在的成片文件夹里面（或者反过来），换一个文件夹吧。")
        case .notAFolder:
            return String(localized: "选的不是文件夹。")
        case nil:
            return String(localized: "没搬成，成片还在原来的位置：\(error.localizedDescription)")
        }
    }
}
