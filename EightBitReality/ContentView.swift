import SwiftUI
import RealityKit

struct ContentView: View {
    // 没入空間を開くための「鍵」
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    var body: some View {
        VStack {
            Text("準備完了")
                .font(.title)
            
            Text("ボタンを押すとマリオの世界が始まります")
                .font(.caption)
                .padding(.bottom)

            // このボタンを押すと、ImmersiveViewが起動します
            Button("Start 8-Bit Mode") {
                Task {
                    // 没入空間を開く
                    await openImmersiveSpace(id: "ImmersiveSpace")
                }
            }
            .font(.extraLargeTitle)
            .padding()
        }
    }
}
