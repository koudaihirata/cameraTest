//
//  GridOverlayView.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/19.
//

import UIKit

/// 画面全体に３×３のグリッドを描くオーバーレイビュー
class GridOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false  // タップは下のカメラに通す
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)

        let w = rect.width / 3
        let h = rect.height / 3

        // 縦線（1/3, 2/3）
        for i in 1...2 {
            let x = CGFloat(i) * w
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.height))
        }

        // 横線（1/3, 2/3）
        for i in 1...2 {
            let y = CGFloat(i) * h
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
        }

        ctx.strokePath()
    }
}

