import AppKit
import NocchiKit
import SwiftUI

/// 菜单栏菜单。
struct MenuContent: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Button("屏幕快门") { Darkroom.shared.screenShutter() }
            .keyboardShortcut("s", modifiers: [.control, .option, .command])
        Button("自拍") { NotchController.shared.enterSelfie() }
            .keyboardShortcut("f", modifiers: [.control, .option, .command])
        Button("大头贴机") { PhotoBoothController.shared.start() }
            .keyboardShortcut("b", modifiers: [.control, .option, .command])
        Button("冲印照片…") { PhotoImport.chooseFiles() }
        Button("从「照片」图库冲印…") { PhotoImport.choosePhotosLibrary() }

        Divider()

        Picker("机身", selection: $model.bodyID) {
            ForEach(CameraBody.allCases.filter(\.isAvailable)) { body in
                Text(body.displayName).tag(body.rawValue)
            }
        }
        Picker("胶卷", selection: $model.stockID) {
            ForEach(model.stocks) { stock in
                Label {
                    Text("\(stock.name)  ·  \(stock.exposures) 张")
                } icon: {
                    if let icon = FilmArt.menuIcon(for: stock) {
                        Image(nsImage: icon)
                    } else {
                        Image(systemName: "film")
                    }
                }
                .tag(stock.id)
            }
        }
        Picker("相纸", selection: $model.instantFormat) {
            ForEach(FilmFormat.instantChoices) { format in
                Text(format.displayName).tag(format)
            }
        }
        Text("这一卷：\(model.roll.counterText)")
        Toggle("安静模式", isOn: $model.quietMode)

        Divider()

        Button("打开相册") { WindowManager.shared.showAlbum() }
        Button("收起桌面上的照片") { DesktopBoard.shared.collectAll() }
        Button("在 Finder 中打开照片文件夹") {
            NSWorkspace.shared.open(Services.library.printsRoot)
        }

        Divider()

        Button("设置…") { WindowManager.shared.showSettings() }
            .keyboardShortcut(",", modifiers: .command)
        Button("退出 Nocchi") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
