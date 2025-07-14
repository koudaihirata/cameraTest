//
//  CameraThreeView.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/12.
//

import SwiftUI
import UIKit
import AVFoundation

/// CameraThree（UIViewController）を SwiftUI に埋め込むためのラッパー
struct CameraThreeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraThree {
        return CameraThree()
    }

    func updateUIViewController(_ uiViewController: CameraThree, context: Context) {
        // 必要な更新があればここに
    }
}

