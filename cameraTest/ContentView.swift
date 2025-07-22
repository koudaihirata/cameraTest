//
//  ContentView.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/11.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?  // 必要なら

    var body: some View {
        VStack {
            Button("カメラ起動（AVCaptureSession）ファイル別") {
                isShowingCamera = true
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraViewController()
                    .edgesIgnoringSafeArea(.all)
            }
            
//            Button("カメラ起動（AVCaptureSession）") {
//                isShowingCamera = true
//            }
//            .fullScreenCover(isPresented: $isShowingCamera) {
//                CameraThreeView()
//                    .edgesIgnoringSafeArea(.all)
//            }
            
//            Button("カメラ起動:白い背景") {
//                isShowingCamera = true
//            }
//            .sheet(isPresented: $isShowingCamera) {
//                ImagePickerWhite()
//            }
            
//            Button("カメラ起動:直接") {
//                isShowingCamera = true
//            }
//            .fullScreenCover(isPresented: $isShowingCamera) {
//                ImagePickerDirectly(sourceType: .camera) { image in
//                    // キャプチャ後のコールバック
//                    capturedImage = image
//                    isShowingCamera = false
//                }
//            }

            // 取得した画像を表示したい場合
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }
        }
    }
}
