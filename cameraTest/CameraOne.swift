//  camera.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/11.
//

import SwiftUI
import UIKit
import AVFoundation

/// SwiftUI で直接 UIImagePickerController（カメラ）を呼び出すラッパー
struct ImagePickerDirectly: UIViewControllerRepresentable {
    enum PickerSource { case camera, photoLibrary }
    let sourceType: PickerSource
    let didFinishPicking: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        // カメラ権限チェック
        if sourceType == .camera {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            guard status == .authorized || status == .notDetermined else {
                // 権限がない場合は何もしない UIViewController を返す
                return UIImagePickerController()
            }
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in }
            }
        }

        let picker = UIImagePickerController()
        picker.modalPresentationStyle = .fullScreen
        picker.modalPresentationCapturesStatusBarAppearance = true
        picker.edgesForExtendedLayout = [.top, .bottom]
        picker.sourceType = (sourceType == .camera ? .camera : .photoLibrary)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 更新の必要なし
    }

    // Delegate クラス
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerDirectly
        init(_ parent: ImagePickerDirectly) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true) {
                if let img = info[.originalImage] as? UIImage {
                    self.parent.didFinishPicking(img)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
