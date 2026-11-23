import AppKit
import AVFoundation
import NocchiKit
import SwiftUI

/// 刘海里的摄像头。摄像头一开，刘海旁的绿灯就亮——相机铺「营业中」。
final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = CameraService()

    enum CameraError: LocalizedError {
        case denied
        case unavailable
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .denied: return "需要摄像头权限（系统设置 → 隐私与安全性 → 摄像头）"
            case .unavailable: return "没有找到摄像头"
            case .captureFailed: return "没拍到，再试一次"
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

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "摄像头出错了"
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
                guard self.session.isRunning, self.pending == nil else {
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

    private func configureIfNeeded() throws {
        guard !configured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video) else { throw CameraError.unavailable }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)
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
        alert.messageText = "Nocchi 需要使用摄像头"
        alert.informativeText = "自拍和大头贴机要用到刘海里的摄像头。请在「系统设置 → 隐私与安全性 → 摄像头」里打开 Nocchi，然后再试一次。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// 摄像头实时预览。
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool
    var isRunning: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.attach(session: session)
        view.applyMirroring(mirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.applyMirroring(mirrored)
    }
}

final class PreviewView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

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

    func attach(session: AVCaptureSession) {
        previewLayer.session = session
    }

    func applyMirroring(_ mirrored: Bool) {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}
