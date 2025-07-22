//
//  CameraViewController.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/22.
//

import UIKit
import AVFoundation
import CoreLocation

class CameraV: UIViewController,
                                 AVCapturePhotoCaptureDelegate,
                                 CLLocationManagerDelegate {
    // — カメラ関連 —
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

    // — 位置情報管理 —
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?

    // — ヘルスケア(歩数) —
    private let stepsHK = StepsHealthKit()

    // — グリッド表示フラグ —
    private var isGridVisible = false
    private var gridLayer: CAShapeLayer?

    /// ズーム倍率管理
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    private var currentZoomFactor: CGFloat = 1.0

    // — 露出バイアス管理 —
    private var initialExposureBias: Float = 0
    private var minExposureFactor: Float = 0
    private var maxExposureFactor: Float = 0
    private var currentExposureFactor: Float = 0

    // 撮影ボタン
    private lazy var captureButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.cornerRadius = 32
        b.backgroundColor = .white
        b.addTarget(self, action: #selector(didTapCapture), for: .touchUpInside)
        return b
    }()

    // キャンセルボタン
    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("キャンセル", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        return btn
    }()

    // グリッドトグルボタン
    private lazy var gridToggleButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let icon = UIImage(systemName: "square.grid.3x3", withConfiguration: config)
        b.setImage(icon, for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(didTapGridToggle), for: .touchUpInside)
        return b
    }()

    /// 露出バイアスを可視化する縦向きゲージ
    private lazy var exposureGauge: UIProgressView = {
        let g = UIProgressView(progressViewStyle: .bar)
        g.transform = CGAffineTransform(rotationAngle: .pi)
        g.trackTintColor    = UIColor.white.withAlphaComponent(0.3)
        g.progressTintColor = UIColor.systemYellow
        g.translatesAutoresizingMaskIntoConstraints = false
        return g
    }()

    // カメラ切り替えボタン
    private lazy var switchButton: UIButton = {
        let b = UIButton(type: .system)
        let icon = UIImage(systemName: "camera.rotate")
        b.setImage(icon, for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(didTapSwitch), for: .touchUpInside)
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // カメラの準備
        setupCaptureSession()

        // 位置情報の初期設定
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        // 明るさスライド用パンジェスチャー
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleExposurePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        setupPreview()
        setupUI()
        setupZoom()
        startSession()
        setupTapToFocus()

        // セッションの開始
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    // MARK: — セッション & 入出力設定

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        // バックカメラ入力
        guard let backInput = makeDeviceInput(position: .back) else {
            print("バックカメラの入力作成に失敗")
            return
        }
        captureSession.addInput(backInput)
        currentInput = backInput

        // ビデオ出力
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        // 写真出力
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    private func makeDeviceInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            return nil
        }
        return input
    }

    // MARK: — プレビュー & UI

    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    private func setupUI() {
        // キャンセルボタン
        view.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // 撮影ボタン
        view.addSubview(captureButton)
        NSLayoutConstraint.activate([
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 64),
            captureButton.heightAnchor.constraint(equalToConstant: 64),
        ])

        // カメラ切り替えボタン
        view.addSubview(switchButton)
        NSLayoutConstraint.activate([
            switchButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 100),
            switchButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 40),
            switchButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        // グリッドトグルボタン
        view.addSubview(gridToggleButton)
        NSLayoutConstraint.activate([
            gridToggleButton.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -100),
            gridToggleButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            gridToggleButton.widthAnchor.constraint(equalToConstant: 40),
            gridToggleButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: — ズーム & フォーカス設定

    private func setupZoom() {
        guard let device = currentInput?.device else { return }

        // 露出バイアス
        minExposureFactor    = device.minExposureTargetBias
        maxExposureFactor    = device.maxExposureTargetBias
        currentExposureFactor = device.exposureTargetBias

        // ズーム倍率
        minZoomFactor    = device.minAvailableVideoZoomFactor
        maxZoomFactor    = device.maxAvailableVideoZoomFactor
        currentZoomFactor = 1.0

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }

    private func setupTapToFocus() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tap)
    }

    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = currentInput?.device else { return }
        var newZoom = currentZoomFactor * pinch.scale
        newZoom = max(minZoomFactor, min(newZoom, maxZoomFactor))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
        } catch {
            print("ズーム設定に失敗: \(error)")
        }
        if pinch.state == .ended {
            currentZoomFactor = newZoom
            pinch.scale = 1.0
        }
    }

    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let point = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        guard let device = currentInput?.device,
              device.isFocusPointOfInterestSupported,
              device.isExposurePointOfInterestSupported else { return }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
            animateFocusIndicator(at: location)
        } catch {
            print("フォーカス／露出設定に失敗: \(error)")
        }
    }

    private func animateFocusIndicator(at point: CGPoint) {
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.white.cgColor
        focusView.layer.borderWidth = 2
        focusView.backgroundColor = .clear
        focusView.alpha = 0
        view.addSubview(focusView)

        UIView.animateKeyframes(withDuration: 0.8, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                focusView.alpha = 1
                focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.6) {
                focusView.alpha = 0
            }
        }, completion: { _ in
            focusView.removeFromSuperview()
        })
    }

    // MARK: — ボタンアクション

    @objc private func didTapCancel() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func didTapCapture() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func didTapSwitch() {
        guard let currentInput = currentInput else { return }
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        let newPos: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
        if let newInput = makeDeviceInput(position: newPos),
           captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            self.currentInput = newInput
        } else {
            captureSession.addInput(currentInput)
        }
        captureSession.commitConfiguration()
    }

    @objc private func didTapGridToggle() {
        isGridVisible.toggle()
        if isGridVisible {
            addGridOverlay()
            gridToggleButton.tintColor = .systemYellow
        } else {
            gridLayer?.removeFromSuperlayer()
            gridToggleButton.tintColor = .white
        }
    }

    // MARK: — 露出バイアス操作

    @objc private func handleExposurePan(_ pan: UIPanGestureRecognizer) {
        guard let device = currentInput?.device,
              device.isExposureModeSupported(.continuousAutoExposure) else { return }
        if pan.state == .began {
            initialExposureBias = device.exposureTargetBias
        }
        let translation = pan.translation(in: view)
        let maxBias = device.maxExposureTargetBias
        let minBias = device.minExposureTargetBias
        let delta = Float(-translation.y / 2000) * (maxBias - minBias)
        let newBias = max(minBias, min(maxBias, initialExposureBias + delta))
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(newBias, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            print("露出バイアス設定失敗: \(error)")
        }
        if pan.state == .ended || pan.state == .cancelled {
            pan.setTranslation(.zero, in: view)
        }
        let normalized = (newBias - minExposureFactor) / (maxExposureFactor - minExposureFactor)
        exposureGauge.setProgress(normalized, animated: true)
    }

    @objc private func exposureSliderChanged(_ slider: UISlider) {
        guard let device = currentInput?.device,
              device.isExposureModeSupported(.continuousAutoExposure) else { return }
        let bias = slider.value
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(bias, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            print("露出バイアス設定に失敗: \(error)")
        }
        currentExposureFactor = bias
    }

    // MARK: — ライフサイクル

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = videoOrientation()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        addCaptureButtonRing()
    }

    private func addCaptureButtonRing() {
        captureButton.layer.sublayers?
            .filter { $0.name == "captureRing" }
            .forEach { $0.removeFromSuperlayer() }
        let diameter = max(captureButton.bounds.width, captureButton.bounds.height) + 8
        let rect = CGRect(x: -4, y: -4, width: diameter, height: diameter)
        let ring = CAShapeLayer()
        ring.name = "captureRing"
        ring.path = UIBezierPath(ovalIn: rect).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.white.cgColor
        ring.lineWidth = 4
        captureButton.layer.insertSublayer(ring, at: 0)
    }

    private func addGridOverlay() {
        gridLayer?.removeFromSuperlayer()
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        let w = view.bounds.width
        let h = view.bounds.height
        for i in 1...2 {
            let x = CGFloat(i) * w / 3
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: h))
        }
        for i in 1...2 {
            let y = CGFloat(i) * h / 3
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: w, y: y))
        }
        layer.path = path.cgPath
        layer.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
        layer.lineWidth = 1
        layer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(layer)
        gridLayer = layer
    }

    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func videoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:             return .portrait
        case .landscapeLeft:        return .landscapeRight
        case .landscapeRight:       return .landscapeLeft
        case .portraitUpsideDown:   return .portraitUpsideDown
        default:                    return .portrait
        }
    }

    deinit {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let steps = stepsHK.steps
        print("現在の歩数: \(steps)")

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        DispatchQueue.main.async {
            let previewVC = PhotoPreviewViewController(
                captured: image,
                coordinate: self.lastLocation?.coordinate,
                steps: steps
            )
            previewVC.modalPresentationStyle = .fullScreen
            self.present(previewVC, animated: true)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得失敗: \(error)")
    }
}

// MARK: - ビデオデータ出力デリゲート

extension CameraV: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // フレームごとの処理（例えば画像解析など）
    }
}
