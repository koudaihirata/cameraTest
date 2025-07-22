//
//  CameraTwe.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/11.
//

import SwiftUI
import UIKit
import AVFoundation

/// SwiftUI のシートに「真っ白ページ」を出すラッパー
struct ImagePickerWhite: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraView {
        CameraView()
    }
    func updateUIViewController(_ uiViewController: CameraView, context: Context) {}
}

/// 中身は真っ白な UIViewController。表示されたらすぐカメラを起動する
class CameraView: UIViewController,
                            UIImagePickerControllerDelegate,
                            UINavigationControllerDelegate {

    private var hasLaunchedCamera = false
    
    // ─── ここで写真を表示する UIImageView を用意
    private let capturedImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 背景を systemBackground（ライト→白／ダーク→黒）にしておく
        view.backgroundColor = .systemBackground
        
        capturedImageView.contentMode = .scaleAspectFill
        capturedImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(capturedImageView)
        
        view.addSubview(capturedImageView)
        NSLayoutConstraint.activate([
            capturedImageView.widthAnchor.constraint(equalToConstant: 240),
            capturedImageView.heightAnchor.constraint(equalToConstant: 180),
            capturedImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            capturedImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let retakeButton = UIButton(type: .system)
        retakeButton.setTitle("再撮影", for: .normal)
        retakeButton.titleLabel?.font = .systemFont(ofSize: 18)
        retakeButton.translatesAutoresizingMaskIntoConstraints = false
        retakeButton.addTarget(self, action: #selector(didTapRetake), for: .touchUpInside)
        view.addSubview(retakeButton)
        NSLayoutConstraint.activate([
            retakeButton.topAnchor.constraint(equalTo: capturedImageView.bottomAnchor, constant: 80),
            retakeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        let sendButton = UIButton(type: .system)
        sendButton.setTitle("送信", for: .normal)
        sendButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        view.addSubview(sendButton)
        NSLayoutConstraint.activate([
            sendButton.topAnchor.constraint(equalTo: capturedImageView.bottomAnchor, constant: 120),
            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func didTapRetake() {
        // 再度カメラを起動する処理
        hasLaunchedCamera = false
        startCamera()
    }
    
    @objc private func didTapSend() {
        guard let image = capturedImageView.image else { return }
        // ここで image をサーバなどに送信する処理を書く
        print("送信する画像: \(image)")

        // 送信後、必要なら中間ページ（CameraViewController）を閉じる
        dismiss(animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard !hasLaunchedCamera else { return }
        hasLaunchedCamera = true
        startCamera()
    }

    private func startCamera() {
        confirmCameraAuthorizationStatus { [weak self] isAuthorized in
            guard let self = self, isAuthorized,
                  UIImagePickerController.isSourceTypeAvailable(.camera)
            else { return }

            let picker = UIImagePickerController()
            picker.modalPresentationStyle = .fullScreen
            picker.sourceType = .camera
            picker.delegate = self
            self.present(picker, animated: true)
        }
    }

    private func confirmCameraAuthorizationStatus(result: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { result(granted) }
            }

        case .denied, .restricted:
            result(false)

        @unknown default:
            result(false)
        }
    }

    // MARK: –– UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true) {
            // 取得した画像をキャプチャビューにセット
            if let image = info[.originalImage] as? UIImage {
                self.capturedImageView.image = image
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            // キャンセルしたら中間ページも閉じる
            self.dismiss(animated: true, completion: nil)
        }
    }
}

