import AppKit
import Combine
import NocchiKit

/// 全局设置与当前装填的机身 / 胶卷。
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    private enum Keys {
        static let body = "camera.body"
        static let stock = "film.stock"
        static let quiet = "quietMode"
        static let takeOver = "takeOverScreenshots"
        static let countdown = "selfieCountdown"
        static let developSeconds = "developSeconds"
        static let volume = "volume"
        static let roll = "film.roll"
        static let custom = "film.customStocks"
        static let printDate = "print.showDate"
        static let layer = "photo.defaultLayer"
        static let welcome = "welcome.seen"
        static let caption = "print.defaultCaption"
        static let dockIcon = "app.showsDockIcon"
        static let instantFormat = "print.instantFormat"
        static let cameraDevice = "camera.deviceID"
        static let mirrorSelfie = "camera.mirrorSelfie"
    }

    private let defaults = UserDefaults.standard

    @Published var bodyID: String {
        didSet { defaults.set(bodyID, forKey: Keys.body) }
    }

    @Published var stockID: String {
        didSet {
            defaults.set(stockID, forKey: Keys.stock)
            if roll.stockID != stockID { reloadRoll() }
        }
    }

    @Published var quietMode: Bool {
        didSet {
            defaults.set(quietMode, forKey: Keys.quiet)
            SoundPlayer.shared.isMuted = quietMode
        }
    }

    @Published var takeOverScreenshots: Bool {
        didSet {
            defaults.set(takeOverScreenshots, forKey: Keys.takeOver)
            onTakeOverChange?(takeOverScreenshots)
        }
    }

    @Published var selfieCountdown: Bool {
        didSet { defaults.set(selfieCountdown, forKey: Keys.countdown) }
    }

    /// 即显相机完全显影需要的秒数（不甩的情况下）。
    @Published var developSeconds: Double {
        didSet { defaults.set(developSeconds, forKey: Keys.developSeconds) }
    }

    @Published var volume: Double {
        didSet {
            defaults.set(volume, forKey: Keys.volume)
            SoundPlayer.shared.volume = Float(volume)
        }
    }

    @Published var printDate: Bool {
        didSet { defaults.set(printDate, forKey: Keys.printDate) }
    }

    /// 新照片默认的题字（空字符串表示不写）。
    @Published var defaultCaption: String {
        didSet { defaults.set(defaultCaption, forKey: Keys.caption) }
    }

    /// 新照片默认放在浮动层还是桌面层。
    @Published var defaultLayer: DeskPlacement.Layer {
        didSet { defaults.set(defaultLayer.rawValue, forKey: Keys.layer) }
    }

    /// 在程序坞显示图标（关掉后只住在菜单栏和刘海里）。
    @Published var showsDockIcon: Bool {
        didSet {
            defaults.set(showsDockIcon, forKey: Keys.dockIcon)
            applyActivationPolicy()
        }
    }

    /// 即显相机用的相纸（方形 / 迷你 / 宽幅 / 冲印小照）。
    @Published var instantFormat: FilmFormat {
        didSet {
            if !FilmFormat.instantChoices.contains(instantFormat) {
                instantFormat = .instantSquare
                return
            }
            defaults.set(instantFormat.rawValue, forKey: Keys.instantFormat)
        }
    }

    /// 选中的摄像头（`AVCaptureDevice.uniqueID`）；nil 表示系统默认摄像头。
    @Published var cameraDeviceID: String? {
        didSet { defaults.set(cameraDeviceID, forKey: Keys.cameraDevice) }
    }

    /// 自拍画面镜像（像照镜子）。
    @Published var mirrorSelfie: Bool {
        didSet { defaults.set(mirrorSelfie, forKey: Keys.mirrorSelfie) }
    }

    @Published private(set) var roll: FilmRoll
    @Published private(set) var customStocks: [FilmStock]

    var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Keys.welcome) }
        set { defaults.set(newValue, forKey: Keys.welcome) }
    }

    var onTakeOverChange: ((Bool) -> Void)?

    var currentBody: CameraBody { CameraBody(rawValue: bodyID) ?? .instant }
    var stocks: [FilmStock] { FilmCatalog.builtIn + customStocks }
    var currentStock: FilmStock { FilmCatalog.stock(id: stockID, custom: customStocks) }

    func stock(id: String) -> FilmStock { FilmCatalog.stock(id: id, custom: customStocks) }

    private init() {
        let d = UserDefaults.standard
        bodyID = d.string(forKey: Keys.body) ?? CameraBody.instant.rawValue
        let stockID = d.string(forKey: Keys.stock) ?? FilmCatalog.defaultStock.id
        self.stockID = stockID
        quietMode = d.object(forKey: Keys.quiet) as? Bool ?? false
        takeOverScreenshots = d.object(forKey: Keys.takeOver) as? Bool ?? false
        selfieCountdown = d.object(forKey: Keys.countdown) as? Bool ?? true
        developSeconds = d.object(forKey: Keys.developSeconds) as? Double ?? 15
        volume = d.object(forKey: Keys.volume) as? Double ?? 0.8
        printDate = d.object(forKey: Keys.printDate) as? Bool ?? true
        defaultCaption = d.string(forKey: Keys.caption) ?? PhotoRecord.defaultCaption
        defaultLayer = DeskPlacement.Layer(rawValue: d.string(forKey: Keys.layer) ?? "") ?? .floating
        showsDockIcon = d.object(forKey: Keys.dockIcon) as? Bool ?? true
        let format = FilmFormat(rawValue: d.string(forKey: Keys.instantFormat) ?? "") ?? .instantSquare
        instantFormat = FilmFormat.instantChoices.contains(format) ? format : .instantSquare
        cameraDeviceID = d.string(forKey: Keys.cameraDevice)
        mirrorSelfie = d.object(forKey: Keys.mirrorSelfie) as? Bool ?? true

        var custom: [FilmStock] = []
        if let data = d.data(forKey: Keys.custom), let decoded = try? JSONDecoder().decode([FilmStock].self, from: data) {
            custom = decoded
        }
        customStocks = custom

        if let data = d.data(forKey: Keys.roll), let decoded = try? JSONDecoder().decode(FilmRoll.self, from: data), decoded.stockID == stockID {
            roll = decoded
        } else {
            roll = FilmRoll(stock: FilmCatalog.stock(id: stockID, custom: custom))
        }
    }

    func applyRuntimeSettings() {
        SoundPlayer.shared.isMuted = quietMode
        SoundPlayer.shared.volume = Float(volume)
        applyActivationPolicy()
    }

    /// 普通 App（程序坞图标 + 主菜单）或只住在菜单栏里。
    func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = showsDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }

    /// 拍一张。返回 true 表示这次之后胶卷拍完、已自动换上新卷。
    @discardableResult
    func consumeExposure(frames: Int) -> Bool {
        roll.expose(frames: frames)
        var reloaded = false
        if roll.isFinished {
            roll.reload(with: currentStock)
            reloaded = true
        }
        saveRoll()
        return reloaded
    }

    func reloadRoll() {
        roll.reload(with: currentStock)
        saveRoll()
    }

    private func saveRoll() {
        if let data = try? JSONEncoder().encode(roll) {
            defaults.set(data, forKey: Keys.roll)
        }
    }

    func addCustomStock(_ stock: FilmStock) {
        customStocks.append(stock)
        saveCustomStocks()
    }

    func removeCustomStock(id: String) {
        customStocks.removeAll { $0.id == id }
        saveCustomStocks()
        if stockID == id { stockID = FilmCatalog.defaultStock.id }
    }

    private func saveCustomStocks() {
        if let data = try? JSONEncoder().encode(customStocks) {
            defaults.set(data, forKey: Keys.custom)
        }
    }
}
