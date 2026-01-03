import SwiftUI

@main
struct EightBitRealityApp: App {
    var body: some Scene {
        // 1. アプリ起動時に最初に表示されるウィンドウ
        WindowGroup {
            ContentView()
        }
        // 複数ウィンドウのサポートを明示（Info.plistの設定と連動）
        .windowStyle(.automatic)

        // 2. ボタンを押した後に開く没入空間
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
        // 没入空間に入った時のスタイル設定
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
