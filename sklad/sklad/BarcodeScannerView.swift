//
//  BarcodeScannerView.swift
//  sklad
//
//  Обёртка над AVFoundation для сканирования штрихкодов.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

struct BarcodeScannerView: UIViewControllerRepresentable {

    var playFeedbackOnScan: Bool = true
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.playFeedbackOnScan = playFeedbackOnScan
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.playFeedbackOnScan = playFeedbackOnScan
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var playFeedbackOnScan: Bool = true
    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var lastScannedCode: String?
    private var lastScannedTime: Date?
    private let scanCooldown: TimeInterval = 1.5

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8,
                .ean13,
                .upce,
                .code128
            ]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.layer.bounds
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }

        let now = Date()
        if let last = lastScannedCode, let time = lastScannedTime,
           last == code, now.timeIntervalSince(time) < scanCooldown {
            return
        }

        lastScannedCode = code
        lastScannedTime = now

        if playFeedbackOnScan {
            AudioServicesPlaySystemSound(1057)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        onCodeScanned?(code)
    }
}

