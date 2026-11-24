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
        static let openAlbumOnLaunch = "app.openAlbumOnLaunch"
        static let instantTemplate = "print.defaultInstantTemplate"
        static let boothTemplate = "booth.defaultTemplate"
        static let boothFormat = "booth.format"
        static let boothMonochrome = "booth.monochrome"
        static let captionFont = "print.captionFont"
        static let autoOpenDecorate = "editor.autoOpenAfterDeveloping"
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
        didSet {
            defaults.set(cameraDeviceID, forKey: Keys.cameraDevice)
            CameraService.shared.setPreferredDevice(cameraDeviceID)
        }
    }

    /// 自拍画面镜像（像照镜子）。
    /// 启动时打开相册（卡片盒）。
    @Published var openAlbumOnLaunch: Bool {
        didSet { defaults.set(openAlbumOnLaunch, forKey: Keys.openAlbumOnLaunch) }
    }

    @Published var mirrorSelfie: Bool {
        didSet { defaults.set(mirrorSelfie, forKey: Keys.mirrorSelfie) }
    }

    /// 即显相片（自拍、屏幕快门、冲印照片）默认用的相纸模板；当前相纸用不了时用「经典」。
    @Published var defaultInstantTemplateID: String {
        didSet { defaults.set(defaultInstantTemplateID, forKey: Keys.instantTemplate) }
    }

    /// 大头贴机的默认相框。「选相框」从这里开始；在大头贴机里换了，下次就从换好的那款开始。
    @Published var defaultBoothTemplateID: String {
        didSet { defaults.set(defaultBoothTemplateID, forKey: Keys.boothTemplate) }
    }

    /// 大头贴机的版式：四格条或四宫格。
    @Published var boothFormat: FilmFormat {
        didSet {
            if !FilmFormat.boothChoices.contains(boothFormat) {
                boothFormat = .boothStrip
                return
            }
            defaults.set(boothFormat.rawValue, forKey: Keys.boothFormat)
        }
    }

    /// 大头贴机拍黑白（照相亭黑白 400，或者装着的黑白卷）。
    @Published var boothMonochrome: Bool {
        didSet { defaults.set(boothMonochrome, forKey: Keys.boothMonochrome) }
    }

    /// 新照片的题字字体。
    @Published var defaultCaptionFont: CaptionFont {
        didSet { defaults.set(defaultCaptionFont.rawValue, forKey: Keys.captionFont) }
    }

    /// 相片显影完成后自动打开装饰台（默认关）。
    @Published var autoOpenDecorate: Bool {
        didSet { defaults.set(autoOpenDecorate, forKey: Keys.autoOpenDecorate) }
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
        openAlbumOnLaunch = d.object(forKey: Keys.openAlbumOnLaunch) as? Bool ?? true
        defaultInstantTemplateID = d.string(forKey: Keys.instantTemplate) ?? TemplateCatalog.classic.id
        defaultBoothTemplateID = d.string(forKey: Keys.boothTemplate) ?? TemplateCatalog.defaultBoothID
        let boothFormat = FilmFormat(rawValue: d.string(forKey: Keys.boothFormat) ?? "") ?? .boothStrip
        self.boothFormat = FilmFormat.boothChoices.contains(boothFormat) ? boothFormat : .boothStrip
        boothMonochrome = d.object(forKey: Keys.boothMonochrome) as? Bool ?? false
        defaultCaptionFont = CaptionFont(rawValue: d.string(forKey: Keys.captionFont) ?? "") ?? .handwriting
        autoOpenDecorate = d.object(forKey: Keys.autoOpenDecorate) as? Bool ?? false

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

    /// 新照片该用哪款模板：大头贴用默认相框，其余用即显默认模板；这种相纸用不了时回落到「经典」。
    func defaultTemplateID(for format: FilmFormat) -> String {
        let preferred = format.isBooth ? defaultBoothTemplateID : defaultInstantTemplateID
        return TemplateCatalog.resolve(id: preferred, format: format).id
    }

    /// 大头贴机这一条用的胶卷（黑白 / 彩色开关 + 装着的胶卷，见 `FilmCatalog.boothStockID`）。
    func boothStock(monochrome: Bool) -> FilmStock {
        stock(id: FilmCatalog.boothStockID(monochrome: monochrome, loaded: currentStock))
    }

    /// 在即显相纸之间轮换（刘海里的「相纸」小卡）。
    func cycleInstantFormat() {
        let choices = FilmFormat.instantChoices
        let index = choices.firstIndex(of: instantFormat) ?? 0
        instantFormat = choices[(index + 1) % choices.count]
    }

    // MARK: - 机身

    /// 装着大头贴机：自拍、屏幕快门、冲印照片都拍成一条四格大头贴（版式、相框、黑白用大头贴机的设置）。
    var shootsBooth: Bool { currentBody == .photoBooth }

    /// 在能用的机身之间轮换（刘海里的「换相机」）。
    func cycleBody() {
        let choices = CameraBody.allCases.filter(\.isAvailable)
        guard !choices.isEmpty else { return }
        let index = choices.firstIndex(of: currentBody) ?? 0
        bodyID = choices[(index + 1) % choices.count].rawValue
    }

    /// 这台相机用的相纸：即显相机是选好的即显相纸，大头贴机是四格条 / 四宫格。
    var shootingFormat: FilmFormat {
        shootsBooth ? boothSetup().format : instantFormat
    }

    /// 这台相机这一张用的胶卷：大头贴机按黑白开关和装着的胶卷挑（见 `FilmCatalog.boothStockID`）。
    var shootingStock: FilmStock {
        shootsBooth ? boothStock(monochrome: boothMonochrome) : currentStock
    }

    /// 刘海里装着大头贴机时这一条的版式、相框和胶卷（和大头贴机上次的选择一致）。
    func boothSetup() -> BoothSetup {
        let format = FilmFormat.boothChoices.contains(boothFormat) ? boothFormat : .boothStrip
        let template = TemplateCatalog.resolve(id: defaultBoothTemplateID, format: format)
        return BoothSetup(format: format, templateID: template.id, stockID: boothStock(monochrome: boothMonochrome).id)
    }

    /// 刘海里的「相纸」小卡：即显相机换下一种相纸，大头贴机在四格条和四宫格之间切换。
    func cyclePaper() {
        if shootsBooth {
            let choices = FilmFormat.boothChoices
            let index = choices.firstIndex(of: boothFormat) ?? 0
            boothFormat = choices[(index + 1) % choices.count]
        } else {
            cycleInstantFormat()
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
