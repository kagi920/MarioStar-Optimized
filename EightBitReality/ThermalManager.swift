import SwiftUI
import Combine
import Foundation

// デバイスの熱状態を監視するクラス
class ThermalManager: ObservableObject {
    // 熱いかどうかを公開する変数（trueなら熱い）
    @Published var isOverheating: Bool = false
    
    init() {
        // アプリ起動時に監視スタート
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        // 初回チェック
        updateState(ProcessInfo.processInfo.thermalState)
    }
    
    @objc func thermalStateChanged(_ notification: Notification) {
        if let processInfo = notification.object as? ProcessInfo {
            updateState(processInfo.thermalState)
        }
    }
    
    func updateState(_ state: ProcessInfo.ThermalState) {
        // メインスレッドで更新（画面への影響があるため）
        DispatchQueue.main.async {
            switch state {
            case .serious, .critical:
                print("⚠️ 警告: デバイスが過熱しています。パフォーマンスを制限します。")
                self.isOverheating = true
            default:
                print("✅ 状態良好: 通常パフォーマンス")
                self.isOverheating = false
            }
        }
    }
}
