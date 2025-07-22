//
//  CameraThree.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/12.
//

import UIKit
import AVFoundation
import SwiftUI
import CoreLocation

class CameraThree: UIViewController, AVCapturePhotoCaptureDelegate,CLLocationManagerDelegate {
    // カメラ関連
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    
    // 位置情報管理
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    
    // ヘルスケア(歩数)
    private let stepsHK = StepsHealthKit()
    
//    グリッドの表示状態フラグ
    private var isGridVisible = false
    private var gridLayer: CAShapeLayer?
    
    /// ズーム倍率管理
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    private var currentZoomFactor: CGFloat = 1.0
    
//    現在の露出バイアス値とジェスチャー開始時のバイアスを覚えておく
    private var initialExposureBias: Float = 0
    
    // 露出バイアスの内部状態
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
    
//    グリッドトグルボタン
    private lazy var gridToggleButton: UIButton = {
        let b = UIButton(type: .system)
        // SF Symbol のグリッドアイコン
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // カメラの準備
        setupCaptureSession()
        
        // 位置情報の初期設定
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
//        明るさスライド用パンジェスチャー
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
    
//    プレビューをタップしたらフォーカス／露出を合わせるジェスチャーを登録
    private func setupTapToFocus() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tap)
    }
    
    // ピンチに応じてズーム倍率を変える
     @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
         guard let device = currentInput?.device else { return }
         
         // ジェスチャーのスケールから新しい倍率を計算
         var newZoom = currentZoomFactor * pinch.scale
         // min/max の範囲にクランプ
         newZoom = max(minZoomFactor, min(newZoom, maxZoomFactor))
         
         do {
             try device.lockForConfiguration()
             // 即時ズーム（滑らかにしたいときは ramp(toVideoZoomFactor:withRate:) を使えます）
             device.videoZoomFactor = newZoom
             device.unlockForConfiguration()
         } catch {
             print("ズーム設定に失敗: \(error)")
         }
         
         if pinch.state == .ended {
             // ジェスチャー終わりで current を更新、scale をリセット
             currentZoomFactor = newZoom
             pinch.scale = 1.0
         }
     }
    
    @objc private func didTapCancel() {
        // モーダルを閉じる
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func didTapCapture() {
      let settings = AVCapturePhotoSettings()
      // (必要ならフラッシュ設定などいじる)
      photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
//    タップ位置をデバイス座標に変換してフォーカス＆露出
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        // ① タップ位置（画面座標）
        let locationInView = gesture.location(in: view)
        // ② デバイス座標（0…1）に変換
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: locationInView)
        
        guard
          let device = currentInput?.device,
          device.isFocusPointOfInterestSupported,
          device.isExposurePointOfInterestSupported
        else { return }
        
        do {
            try device.lockForConfiguration()
            
            // フォーカス
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
            
            // 露出
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = .autoExpose
            
            // 追加: 露出とフォーカスをロックしたい場合は以下を有効化
            // device.exposureMode = .locked
            
            device.unlockForConfiguration()
            
            // （おまけ）フォーカス位置を示すアニメーションを追加するとUXが向上します
            animateFocusIndicator(at: locationInView)
            
        } catch {
            print("フォーカス／露出設定に失敗: \(error)")
        }
    }
    
    /// 上下スワイプで露出ターゲットバイアスを調整する
    @objc private func handleExposurePan(_ pan: UIPanGestureRecognizer) {
        guard let device = currentInput?.device,
              device.isExposureModeSupported(.continuousAutoExposure)
        else { return }

        // ジェスチャー開始時に現在のバイアスを記憶
        if pan.state == .began {
            initialExposureBias = device.exposureTargetBias
        }

        // 縦移動量を取得（上にスワイプすると y は負、下は正）
        let translation = pan.translation(in: view)
        // 感度：200pt のスワイプでバイアスをフルレンジ変える
        let maxBias = device.maxExposureTargetBias
        let minBias = device.minExposureTargetBias
        let delta = Float(-translation.y / 2000) * (maxBias - minBias)  // 上スワイプでプラス方向

        // 新しいバイアスを clamp
        let newBias = max(minBias, min(maxBias, initialExposureBias + delta))

        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(newBias, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            print("露出バイアス設定失敗: \(error)")
        }
        
        // ジェスチャー終了で翻訳量をリセット（次回の変化量計算を簡単に）
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
        // 内部状態も更新
        currentExposureFactor = bias
    }

    /// タップ位置に小さな円を一瞬表示して「ここに合わせたよ」を可視化
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
    
    // カメラ映像のレイヤーを設置
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    // キャンセルボタン・撮影ボタンの追加と制約
    private func setupUI() {
        // ——— キャンセルボタンを追加 ———
        view.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // ── 撮影ボタン
        view.addSubview(captureButton)
        NSLayoutConstraint.activate([
          captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
          captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
          captureButton.widthAnchor.constraint(equalToConstant: 64),
          captureButton.heightAnchor.constraint(equalToConstant: 64),
        ])
        
        view.addSubview(switchButton)
        NSLayoutConstraint.activate([
            switchButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 100),
            switchButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 40),
            switchButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        view.addSubview(gridToggleButton)
        NSLayoutConstraint.activate([
            // captureButton の左側 20pt
            gridToggleButton.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -100),
            // captureButton と同じ縦位置
            gridToggleButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            // 適当なサイズ
            gridToggleButton.widthAnchor.constraint(equalToConstant: 40),
            gridToggleButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // カメラの向きを画面の向きに合わせる
        if let connection =  self.previewLayer?.connection  {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = self.videoOrientation()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        addCaptureButtonRing()
    }
    
    /// キャプチャボタンの周りにリングを描画する
    private func addCaptureButtonRing() {
        // いったん前のリングがあれば消す
        captureButton.layer.sublayers?
            .filter { $0.name == "captureRing" }
            .forEach { $0.removeFromSuperlayer() }

        // ボタンサイズ＋余白分を計算（ここでは余白8ptずつで16pt増し）
        let ringDiameter = max(captureButton.bounds.width, captureButton.bounds.height) + 8
        let ringRect = CGRect(
            x: -4, y: -4,  // ボタンの左上原点から8ptずらして開始
            width: ringDiameter,
            height: ringDiameter
        )

        // CAShapeLayer で円を描く
        let ringLayer = CAShapeLayer()
        ringLayer.name = "captureRing"
        ringLayer.path = UIBezierPath(ovalIn: ringRect).cgPath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.white.cgColor  // 線の色
        ringLayer.lineWidth = 4                       // 線の太さ

        // ボタンの背面に追加
        captureButton.layer.insertSublayer(ringLayer, at: 0)
    }
    
    /// ３×３グリッドをプレビューの上に重ねる
   private func addGridOverlay() {
       // 既存のグリッドを消す
       gridLayer?.removeFromSuperlayer()

       // 新しいグリッド用の CAShapeLayer を生成
       let layer = CAShapeLayer()
       let path = UIBezierPath()
       let w = view.bounds.width
       let h = view.bounds.height

       // 縦線（幅を1/3・2/3の位置に引く）
       for i in 1...2 {
           let x = CGFloat(i) * w / 3
           path.move(to: CGPoint(x: x, y: 0))
           path.addLine(to: CGPoint(x: x, y: h))
       }
       // 横線（高さを1/3・2/3の位置に引く）
       for i in 1...2 {
           let y = CGFloat(i) * h / 3
           path.move(to: CGPoint(x: 0, y: y))
           path.addLine(to: CGPoint(x: w, y: y))
       }

       layer.path = path.cgPath
       layer.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
       layer.lineWidth = 1
       layer.fillColor = UIColor.clear.cgColor

       // プレビュー層の上に追加
       view.layer.addSublayer(layer)
       gridLayer = layer
   }

    // カメラの向きを調整する関数
    func videoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    // カメラのセットアップ
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video) else {
            print("カメラが見つかりません")
            return
        }
        
        if let backInput = makeDeviceInput(position: .back) {
            captureSession.addInput(backInput)
            currentInput = backInput
        } else {
            print("バックカメラの入力作成に失敗")
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("カメラ入力の追加に失敗しました: \(error)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        // 出力設定（フレームレートなど）
        if let connection = output.connection(with: .video) {
           connection.videoOrientation = videoOrientation() // 画面の向きに合わせて調整
        }
    }
    
    private func makeDeviceInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device)
        else { return nil }
        return input
    }
    
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    // MARK: — UI
    private lazy var switchButton: UIButton = {
        let b = UIButton(type: .system)
        // SF Symbol のアイコンをセット
        let icon = UIImage(systemName: "camera.rotate")
        b.setImage(icon, for: .normal)
        b.tintColor = .white      // アイコンの色
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(didTapSwitch), for: .touchUpInside)
        return b
    }()
    
    // MARK: — 切り替え処理
    @objc private func didTapSwitch() {
        guard let currentInput = currentInput else { return }

        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)

        let newPosition: AVCaptureDevice.Position = (currentInput.device.position == .back)
            ? .front
            : .back

        if let newInput = makeDeviceInput(position: newPosition),
           captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            self.currentInput = newInput
        } else {
            // 切り替え失敗時は元に戻す
            captureSession.addInput(currentInput)
        }

        captureSession.commitConfiguration()
    }
    
    @objc private func didTapGridToggle() {
        isGridVisible.toggle()
        if isGridVisible {
            addGridOverlay()
            gridToggleButton.tintColor = .systemYellow  // 押された見た目
        } else {
            gridLayer?.removeFromSuperlayer()
            gridToggleButton.tintColor = .white
        }
    }

    // MARK: — CoreLocation Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 最後に得られた位置を保存
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得失敗: \(error)")
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        
      let steps = stepsHK.steps
      print("現在の歩数: \(steps)")
    
      guard let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) else {
        return
      }
      // メインスレッドでプレビュー画面を出す
      DispatchQueue.main.async {
        let coordinate = self.lastLocation?.coordinate
        let preview = PhotoPreviewViewController(captured: image, coordinate: coordinate, steps: steps)
        preview.modalPresentationStyle = .fullScreen
        self.present(preview, animated: true, completion: nil)
      }
    }

    // 画面の向きが変わった時の処理
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            // プレビューレイヤーの向きを更新
            if let connection = self.previewLayer?.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = self.videoOrientation()
                }
            }
            // プレビューレイヤーのフレームを更新
            self.previewLayer.frame = self.view.bounds
        }, completion: nil)
    }

    deinit {
        // セッションの停止
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

class PhotoPreviewV: UIViewController, UITextFieldDelegate {
    private let image: UIImage
    private let coordinate: CLLocationCoordinate2D?
    private let steps: Int
    let pholder: String = "動物"

    init(captured: UIImage, coordinate: CLLocationCoordinate2D?, steps: Int) {
      self.image = captured
      self.coordinate = coordinate
        self.steps = steps
    super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.backgroundColor)

        // 背景ビューを作成
        let bgView = UIView()
        bgView.backgroundColor = UIColor(Color.aaaa)
        bgView.layer.cornerRadius = 10
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bgView)
        
        // 画像ビュー
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 10
        iv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iv)

          // 緯度・経度ラベル
        let coordLabel = UILabel()
        coordLabel.numberOfLines = 2
        coordLabel.textAlignment = .center
        coordLabel.textColor = UIColor(Color.textColor)
        coordLabel.translatesAutoresizingMaskIntoConstraints = false
        coordLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)

          if let coord = coordinate {
              coordLabel.text = String(
                format: "緯度: %.6f 経度: %.6f",
                coord.latitude, coord.longitude
              )
          } else {
              coordLabel.text = "位置情報が取得できませんでした"
          }
          view.addSubview(coordLabel)
          
          // 歩数ラベル（ここを追加）
          let stepsLabel = UILabel()
          stepsLabel.textAlignment = .center
          stepsLabel.textColor = UIColor(Color.textColor)
          stepsLabel.translatesAutoresizingMaskIntoConstraints = false
          stepsLabel.text = "歩数: \(steps)"
          stepsLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
          view.addSubview(stepsLabel)
        
        // textのラベル
        let textLabel = UILabel()
        textLabel.textAlignment = .center
        textLabel.textColor = UIColor(Color.textColor)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = "この写真のテーマは？"
        textLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        view.addSubview(textLabel)

        // text
        let themeTextField = UITextField()
        themeTextField.placeholder = pholder
        themeTextField.borderStyle = .roundedRect
        themeTextField.returnKeyType = .done
        themeTextField.delegate = self
        themeTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeTextField)

        // 保存ボタン
        let save = UIButton(type: .system)
        save.setTitle("保存", for: .normal)
        save.titleLabel?.font = .boldSystemFont(ofSize: 18)
        save.backgroundColor = UIColor(Color.buttonColor)
        save.setTitleColor(.white, for: .normal)
        save.layer.cornerRadius = 8
        save.translatesAutoresizingMaskIntoConstraints = false
        save.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        view.addSubview(save)

        //    戻るボタン
        let close = UIButton(type: .system)
        close.setTitle("再撮影", for: .normal)
        close.setTitleColor(UIColor(Color.textColor), for: .normal)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(close)

        // Auto Layout
          NSLayoutConstraint.activate([
            // 背景ビューを画面中央から上に100ptオフセット、幅300×高さ400
            bgView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bgView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            bgView.widthAnchor.constraint(equalToConstant: 300),
            bgView.heightAnchor.constraint(equalToConstant: 400),
            
              // 画像は画面中央から上に100ptオフセット
              iv.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              iv.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
              iv.widthAnchor.constraint(equalToConstant: 280),
              iv.heightAnchor.constraint(equalToConstant: 380),

              // ラベルは画像の下、20pt間隔で配置
              coordLabel.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 10),
              coordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              
              // 歩数ラベルは緯度・経度ラベルの下、5pt
              stepsLabel.topAnchor.constraint(equalTo: coordLabel.bottomAnchor, constant: 5),
              stepsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
              // textのラベル
              textLabel.bottomAnchor.constraint(equalTo: themeTextField.topAnchor, constant: -10),
              textLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              
              // テーマ入力欄
              themeTextField.widthAnchor.constraint(equalToConstant: 300),
              themeTextField.heightAnchor.constraint(equalToConstant: 40),
              themeTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              themeTextField.bottomAnchor.constraint(equalTo: save.topAnchor, constant: -40),
//              themeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
//              themeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
              
              // 保存ボタン
              save.bottomAnchor.constraint(equalTo: close.topAnchor, constant: -10),
              save.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              save.widthAnchor.constraint(equalToConstant: 100),
              save.heightAnchor.constraint(equalToConstant: 44),

              // 戻るボタン
              close.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
              close.centerXAnchor.constraint(equalTo: view.centerXAnchor),
          ])
        
        // --- キーボード通知の登録 ---
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        // 画面タップでキーボードを閉じる
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()  // キーボードを閉じる
        return true
    }
    
    // MARK: — キーボード表示／非表示ハンドラ
    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let kbFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        // 入力欄が隠れないように view の origin.y を上にずらす例
        let offset = kbFrame.height      // お好みで調整
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = -offset
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = 0
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func didTapSave() {
            // 例: POST する JSON データを作成
        let payload: [String: Any] = [
            "latitude": coordinate?.latitude ?? 0,
            "longitude": coordinate?.longitude ?? 0,
            "steps": steps
        ]
        guard let url = URL(string: "https://rihlar-test.kokomeow.com/gcore/create/circle") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("userid-79541130-3275-4b90-8677-01323045aca5", forHTTPHeaderField: "UserID")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
//        JSON にエンコードして body にセットする前に文字列化してログ出力
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            //–– ログ出力用に UTF-8 文字列に変換してプリント
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 JSON Payload: \(jsonString)")
            }
            req.httpBody = jsonData
        } catch {
            print("🔴 JSON エンコード失敗: \(error)")
            return
        }

        // POST 実行
        URLSession.shared.dataTask(with: req) { data, resp, error in
            guard let http = resp as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                print("保存失敗:", error ?? "ステータスコード \( (resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            // 成功したらメインスレッドでモーダルを閉じてトップに戻す
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "保存完了",
                    message: "位置と歩数をサーバに保存しました",
                    preferredStyle: .alert
                )
                alert.addAction(.init(title: "OK", style: .default) { _ in
                    // ルートまで一気に閉じてトップ画面へ
                    self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
                })
                self.present(alert, animated: true)
            }
        }.resume()
    }

  @objc private func didTapClose() {
    dismiss(animated: true, completion: nil)
  }
}


// AVCaptureVideoDataOutputSampleBufferDelegateプロトコルに準拠
extension CameraThree: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // ここでフレームごとの処理を行う（例：画像解析、エフェクト処理など）
    }
}
