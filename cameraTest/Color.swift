//
//  Color.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/12.
//

import SwiftUI

extension Color {
    // 16進数のカラーコードからColorを生成するイニシャライズを追加
    init(hex hexString: String) {
        // 数字だけを取り出す
        let hex = hexString.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        // 整数に変換
        Scanner(string: hex).scanHexInt64(&rgb)
        // 赤・緑・青それぞれの成分を取り出し、0〜1の範囲に正規化
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        
        // SwiftUIのColorのイニシャライザを使ってRGBカラーを作成
        self.init(red: r, green: g, blue: b)
    }
    
    // カラーの定義
    static let textColor = Color(hex: "#4F4936")                // 文字
    static let buttonColor = Color(hex: "#A8EAF0")              // ボタン
    static let subDecorationColor = Color(hex: "#87B6BA")       // サブ装飾
    static let mainDecorationColor = Color(hex: "#98BA87")      // メイン装飾
    static let mainShadowColor = Color(hex: "#87A578")          // メイン装飾影
    static let buttonFrameColor = Color(hex: "#89A77A")         // ボタンの枠
    static let backgroundColor = Color(hex: "#EEEBE1")          // 背景
    static let linkColor = Color(hex: "#3D8BFF")                // リンク
    static let soloModeLine = Color(hex: "#5F874B")             // 個人戦モード選択のボタンの線
    static let mulchModeColor = Color(hex: "#F2E6B8")           // チーム戦モード選択のボタンの背景
    static let mulchModeLine = Color(hex: "#D9C377")            // チーム戦モード選択のボタンの線
    static let separatorLine = Color(hex: "#B2AFA5")            // 線、区切り線
    static let itemBackgroundColor = Color(hex:"#D9D9D9")       // アイテム一個ずつの後ろの色
    static let redColor = Color(hex: "#E13535")                 // VS
    static let recordBackgroundColor = Color(hex: "#E7E3D7")    // 実績の背景色
    static let subuBtnColor = Color(hex:"#F9D5B0")              // サブボタン
    static let subuBtnLineColor = Color(hex: "#BAA987")         // サブボタンの線
    static let subBtnDecorationColor = Color(hex: "#F2E6B8")    // サブ装飾ボタンの色
    
    static let aaaa = Color(hex: "#D9D9D9")
}
