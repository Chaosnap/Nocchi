import AppKit
import AVFoundation
import NocchiKit
import SwiftUI

/// 一台可以用的摄像头。
struct CameraDevice: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        /// Mac 内建摄像头。
        case builtIn
        /// USB 摄像头，或以 Camera Extension 形式提供的虚拟摄像头（OBS、Camo……）。
        case external
        /// iPhone 连续互通摄像头。
        case continuity

        var badge: String {
            switch self {
            case .builtIn: return String(localized: "内建")
            case .external: return String(localized: "外接 / 虚拟")
            case .continuity: return "iPhone"
            }
        }

        var symbolName: String {
            switch self {
            case .builtIn: return "laptopcomputer"
            case .external: return "web.camera"
            case .continuity: return "iphone"
            }
        }
    }

    /// `AVCaptureDevice.uniqueID`。
    let id: String
    let name: String
    let kind: Kind
}

/// 刘海里的摄像头。摄像头一开，刘海旁的绿灯就亮——相机铺「营业中」。
///
/// 可以在设置里换成外接、虚拟或 iPhone 摄像头；所选设备拔掉时自动回落到默认摄像头。
final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = CameraService()

    /// 所有可用的摄像头（主线程更新）。
    @Published private(set) var devices: [CameraDevice] = []
    /// 正在用的摄像头名字（主线程更新）。
    @Published private(set) var activeDeviceName: String?

    enum CameraError: LocalizedError {
        case denied
        case unavailable
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .denied: return String(localized: "需要摄像头权限（系统设置 → 隐私与安全性 → 摄像头）")
            case .unavailable: return String(localized: "没有找到摄像头")
            case .captureFailed: return String(localized: "没拍到，再试一次")
            }
        }
    }

    let session = AVCaptureSession()
    @Published private(set) var isRunning = false

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "app.nocchi.camera")
    private var configured = false
    private var pending: CheckedContinuation<CGImage, Error>?
    private var captureToken = 0
    /// 只在 `queue` 上读写。
    private var preferredDeviceID: String?
    private var currentInput: AVCaptureDeviceInput?
    /// 挂在会话上的预览层和它们要不要镜像（只在 `queue` 上读写）。
    private var previews: [ObjectIdentifier: (layer: AVCaptureVideoPreviewLayer, mirrored: Bool)] = [:]
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDevices()
        })
        observers.append(center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { [weak self] note in
            self?.deviceDisconnected(note.object as? AVCaptureDevice)
        })
    }

    // MARK: - Devices

    private static func discovery() -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
    }

    private static func kind(of device: AVCaptureDevice) -> CameraDevice.Kind {
        switch device.deviceType {
        case .builtInWideAngleCamera: return .builtIn
        case .continuityCamera: return .continuity
        default: return .external
        }
    }

    /// 重新列出摄像头（设置页打开时、插拔设备时）。
    func refreshDevices() {
        let found = Self.discovery().devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName, kind: Self.kind(of: $0)) }
        DispatchQueue.main.async {
            self.devices = found
        }
    }

    /// 换摄像头（nil = 系统默认）。会话已经配好时立刻换输入。
    func setPreferredDevice(_ id: String?) {
        queue.async {
            self.preferredDeviceID = id
            guard self.configured else { return }
            self.session.beginConfiguration()
            try? self.swapInput()
            self.session.commitConfiguration()
            self.reapplyMirroring()
        }
    }

    private func resolveDevice() -> AVCaptureDevice? {
        if let id = preferredDeviceID, let device = AVCaptureDevice(uniqueID: id), device.isConnected {
            return device
        }
        return AVCaptureDevice.default(for: .video) ?? Self.discovery().devices.first
    }

    /// 在 `queue` 上、beginConfiguration 之后调用。
    private func swapInput() throws {
        guard let device = resolveDevice() else { throw CameraError.unavailable }
        if currentInput?.device.uniqueID == device.uniqueID { return }
        if let currentInput {
            session.removeInput(currentInput)
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            if let currentInput, session.canAddInput(currentInput) { session.addInput(currentInput) }
            throw CameraError.unavailable
        }
        session.addInput(input)
        currentInput = input
        let name = device.localizedName
        DispatchQueue.main.async { self.activeDeviceName = name }
    }

    private func deviceDisconnected(_ device: AVCaptureDevice?) {
        refreshDevices()
        guard let device else { return }
        queue.async {
            guard self.currentInput?.device.uniqueID == device.uniqueID else { return }
            self.session.beginConfiguration()
            if let input = self.currentInput {
                self.session.removeInput(input)
            }
            self.currentInput = nil
            try? self.swapInput()
            self.session.commitConfiguration()
            self.reapplyMirroring()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    NotchController.shared.showToast(String(localized: "摄像头断开了，换回默认摄像头"), symbol: "video.slash.fill", duration: 3)
                }
            }
        }
    }

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(localized: "摄像头出错了")
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func start() async throws {
        guard await Self.requestAccess() else { throw CameraError.denied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    // 第一次开摄像头时预览层是先挂上、后有连接的：连接有了再把镜像设一遍。
                    self.reapplyMirroring()
                    DispatchQueue.main.async { self.isRunning = true }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    /// 拍一张。超过 `timeout` 秒没拿到照片就报错——保证白屏闪光、布帘这些覆盖层一定会撤掉。
    func capture(timeout: TimeInterval = 5) async throws -> CGImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            queue.async {
                // 没有正在工作的视频连接时（摄像头被别的 App 占着、iPhone 摄像头刚断开……）
                // `capturePhoto` 会抛 Objective-C 异常把 App 弄崩：先查，拍不了就照常报「没拍到」。
                guard self.session.isRunning, self.pending == nil,
                      let connection = self.output.connection(with: .video), connection.isEnabled, connection.isActive else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                self.pending = continuation
                self.captureToken += 1
                let token = self.captureToken
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
                self.queue.asyncAfter(deadline: .now() + timeout) {
                    guard token == self.captureToken, let stuck = self.pending else { return }
                    self.pending = nil
                    stuck.resume(throwing: CameraError.captureFailed)
                }
            }
        }
    }

    // MARK: - 预览层

    /// 把预览层挂到会话上。
    ///
    /// 和启动、停止、换摄像头排在同一条摄像头队列上：`startRunning` / `stopRunning` 会遍历会话的连接，
    /// 主线程同时挂上或摘下预览层会改这张表，AVFoundation 就抛出「Collection was mutated while being
    /// enumerated」让 App 崩溃——2.0 / 2.1 点「自拍」偶尔崩溃的四份崩溃报告都是这样：主线程在
    /// `CameraPreview.makeNSView` 里 `addVideoPreviewLayer`，摄像头队列在 `startRunning`。
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer, mirrored: Bool) {
        queue.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.session = self.session
            CATransaction.commit()
            self.previews[ObjectIdentifier(layer)] = (layer, mirrored)
            Self.applyMirroring(to: layer, mirrored: mirrored)
        }
    }

    /// 摘下预览层（闭包留住它，摘下之后才在这条队列上释放，释放时不会再去改会话）。
    func detachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        queue.async {
            self.previews[ObjectIdentifier(layer)] = nil
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.session = nil
            CATransaction.commit()
        }
    }

    func setPreviewMirroring(_ layer: AVCaptureVideoPreviewLayer, mirrored: Bool) {
        queue.async {
            guard self.previews[ObjectIdentifier(layer)] != nil else { return }
            self.previews[ObjectIdentifier(layer)] = (layer, mirrored)
            Self.applyMirroring(to: layer, mirrored: mirrored)
        }
    }

    /// 在 `queue` 上调用。
    private func reapplyMirroring() {
        for preview in previews.values {
            Self.applyMirroring(to: preview.layer, mirrored: preview.mirrored)
        }
    }

    private static func applyMirroring(to layer: AVCaptureVideoPreviewLayer, mirrored: Bool) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else { return }
        if connection.automaticallyAdjustsVideoMirroring {
            connection.automaticallyAdjustsVideoMirroring = false
        }
        if connection.isVideoMirrored != mirrored {
            connection.isVideoMirrored = mirrored
        }
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        try swapInput()
        guard session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addOutput(output)
        configured = true
    }

    private func finish(_ result: Result<CGImage, Error>) {
        queue.async {
            let continuation = self.pending
            self.pending = nil
            continuation?.resume(with: result)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            finish(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = ImageIOKit.load(data: data) else {
            finish(.failure(CameraError.captureFailed))
            return
        }
        finish(.success(image))
    }
}

/// 摄像头权限：在显示任何覆盖层之前先问，避免系统权限弹窗被挡住。
@MainActor
enum CameraAccess {
    /// 已授权返回 true；未决定时弹出系统权限窗口（此时屏幕上没有任何 Nocchi 覆盖层）。
    static func ensure() async -> Bool {
        await CameraService.requestAccess()
    }

    /// 被拒绝时说明原因，并提供打开系统设置的入口。
    static func presentDeniedAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Nocchi 需要使用摄像头")
        alert.informativeText = String(localized: "自拍和大头贴机要用到刘海里的摄像头。请在「系统设置 → 隐私与安全性 → 摄像头」里打开 Nocchi，然后再试一次。")
        alert.addButton(withTitle: String(localized: "打开系统设置"))
        alert.addButton(withTitle: String(localized: "取消"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// 摄像头实时预览。
///
/// 预览层挂到会话上、摘下来、改镜像都交给 `CameraService` 在摄像头队列上做（见 `attachPreview`），
/// 不会和启动 / 停止摄像头撞在一起。`session` 只能是 `CameraService.shared.session`。
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool
    var isRunning: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.attach(mirrored: mirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.setMirrored(mirrored)
    }

    static func dismantleNSView(_ nsView: PreviewView, coordinator: ()) {
        nsView.detach()
    }
}

final class PreviewView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var attached = false
    private var mirrored: Bool?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // SwiftUI 一般先调 `dismantleNSView`；万一没有，也在摄像头队列上摘下。
        if attached {
            CameraService.shared.detachPreview(previewLayer)
        }
    }

    func attach(mirrored: Bool) {
        guard !attached else {
            setMirrored(mirrored)
            return
        }
        attached = true
        self.mirrored = mirrored
        CameraService.shared.attachPreview(previewLayer, mirrored: mirrored)
    }

    func setMirrored(_ value: Bool) {
        guard attached, mirrored != value else { return }
        mirrored = value
        CameraService.shared.setPreviewMirroring(previewLayer, mirrored: value)
    }

    func detach() {
        guard attached else { return }
        attached = false
        CameraService.shared.detachPreview(previewLayer)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}
