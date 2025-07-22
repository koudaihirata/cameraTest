//
//  PhotoPreviewViewController.swift
//  cameraTest
//
//  Created by Kodai Hirata on 2025/07/22.
//

import UIKit
import CoreLocation
import SwiftUI

class PhotoPreviewViewController: UIViewController, UITextFieldDelegate {
    // MARK: – Properties
    private let image: UIImage
    private let coordinate: CLLocationCoordinate2D?
    private let steps: Int
    private let pholder: String = "動物"

    // MARK: – Initializer
    init(captured: UIImage,
         coordinate: CLLocationCoordinate2D?,
         steps: Int) {
        self.image = captured
        self.coordinate = coordinate
        self.steps = steps
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: – Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.backgroundColor)
        setupLayout()
        registerKeyboardNotifications()
        setupDismissKeyboardGesture()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: – UI Setup
    private func setupLayout() {
        // 背景ビュー
        let bgView = UIView()
        bgView.backgroundColor = UIColor(Color.aaaa)
        bgView.layer.cornerRadius = 10
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bgView)

        // キャプチャ画像
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 10
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iv)

        // 緯度・経度ラベル
        let coordLabel = UILabel()
        coordLabel.numberOfLines = 2
        coordLabel.textAlignment = .center
        coordLabel.textColor = UIColor(Color.textColor)
        coordLabel.font = .systemFont(ofSize: 12, weight: .medium)
        coordLabel.translatesAutoresizingMaskIntoConstraints = false
        if let c = coordinate {
            coordLabel.text = String(format: "緯度: %.6f\n経度: %.6f", c.latitude, c.longitude)
        } else {
            coordLabel.text = "位置情報が取得できませんでした"
        }
        view.addSubview(coordLabel)

        // 歩数ラベル
        let stepsLabel = UILabel()
        stepsLabel.textAlignment = .center
        stepsLabel.textColor = UIColor(Color.textColor)
        stepsLabel.font = .systemFont(ofSize: 12, weight: .medium)
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsLabel.text = "歩数: \(steps)"
        view.addSubview(stepsLabel)

        // テーマ入力ラベル
        let textLabel = UILabel()
        textLabel.textAlignment = .center
        textLabel.textColor = UIColor(Color.textColor)
        textLabel.font = .systemFont(ofSize: 18, weight: .bold)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = "この写真のテーマは？"
        view.addSubview(textLabel)

        // テーマ入力欄
        let themeTextField = UITextField()
        themeTextField.placeholder = pholder
        themeTextField.borderStyle = .roundedRect
        themeTextField.returnKeyType = .done
        themeTextField.delegate = self
        themeTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeTextField)

        // 保存ボタン
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        saveButton.backgroundColor = UIColor(Color.buttonColor)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        view.addSubview(saveButton)

        // 再撮影ボタン
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("再撮影", for: .normal)
        closeButton.setTitleColor(UIColor(Color.textColor), for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)

        // Auto Layout
        NSLayoutConstraint.activate([
            // 背景ビュー
            bgView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bgView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            bgView.widthAnchor.constraint(equalToConstant: 300),
            bgView.heightAnchor.constraint(equalToConstant: 400),

            // 画像ビュー
            iv.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            iv.widthAnchor.constraint(equalToConstant: 280),
            iv.heightAnchor.constraint(equalToConstant: 380),

            // 緯度・経度ラベル
            coordLabel.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 10),
            coordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // 歩数ラベル
            stepsLabel.topAnchor.constraint(equalTo: coordLabel.bottomAnchor, constant: 5),
            stepsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // テキスト入力ラベル
            textLabel.bottomAnchor.constraint(equalTo: themeTextField.topAnchor, constant: -10),
            textLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // テーマ入力欄
            themeTextField.widthAnchor.constraint(equalToConstant: 300),
            themeTextField.heightAnchor.constraint(equalToConstant: 40),
            themeTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            themeTextField.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -40),

            // 保存ボタン
            saveButton.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -10),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 44),

            // 再撮影ボタン
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: – Keyboard Handling
    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let kbFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = -kbFrame.height
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = 0
        }
    }

    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: – UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: – Actions
    @objc private func didTapSave() {
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

        // デバッグ用ログ出力
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 JSON Payload: \(jsonString)")
            req.httpBody = jsonData
        }

        URLSession.shared.dataTask(with: req) { data, resp, error in
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                print("保存失敗:", error ?? "ステータスコード \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "保存完了",
                    message: "位置と歩数をサーバに保存しました",
                    preferredStyle: .alert)
                alert.addAction(.init(title: "OK", style: .default) { _ in
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

