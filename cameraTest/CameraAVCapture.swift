//
//  CameraAVCapture.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/22.
//

import SwiftUI
import UIKit

struct CameraViewController: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode

        func makeUIViewController(context: Context) -> CameraV {
            let vc = CameraV()
            // 必要ならここでプロパティを渡す
            return vc
        }

        func updateUIViewController(_ uiViewController: CameraV, context: Context) {
            // （リアルタイム更新が不要なら空のままでOK）
        }

        // モーダルを閉じるボタンなどを CameraViewController 側から呼び出せるように
        class Coordinator {
            var parent: CameraViewController
            init(parent: CameraViewController) { self.parent = parent }
        }
        func makeCoordinator() -> Coordinator { .init(parent: self) }
}
