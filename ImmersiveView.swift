import SwiftUI
import RealityKit
import ARKit
import RealityKitContent
import UIKit

struct ImmersiveView: View {
    // ----------------------------------------------------------------
    // 1. システム構成
    // ----------------------------------------------------------------
    @State private var arKitSession = ARKitSession()
    // LiDAR高速化（分類なし＝爆速）
    @State private var sceneReconstruction = SceneReconstructionProvider(modes: [])
    @State private var handTracking = HandTrackingProvider()
    
    @State private var meshEntities = [UUID: ModelEntity]()
    @State private var superStarMaterial: ShaderGraphMaterial?
    
    // コードで生成した「完璧な星」のテクスチャ
    @State private var generatedStarTexture: TextureResource?
    
    @State private var lastLeftHandPos: SIMD3<Float>?
    @State private var lastRightHandPos: SIMD3<Float>?
    @State private var currentIntensity: Float = 0.0
    
    @State private var rootEntity = Entity()
    
    // ハテナボックス（星が出る）を管理
    @State private var questionBoxEntity: ModelEntity?

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            
            Task {
                do {
                    // マテリアル読み込み（エラーハンドリング強化）
                    if let material = try? await ShaderGraphMaterial(
                        named: "/Root/SuperStarMaterial",
                        from: "Scene.usda",
                        in: realityKitContentBundle
                    ) {
                        self.superStarMaterial = material
                    }
                    
                    // ★【決定打】画像ファイルを使わず、コードで「完璧な星」を生成
                    // これで「黒い四角」問題は物理的に解決します。
                    self.generatedStarTexture = generatePerfectStarTexture()
                    
                    // ★1. ハテナボックス（星が出る）を作成
                    createQuestionBox()
                    
                    // ★2. レンガブロック（星が出ない）を3つ作成
                    createBrickBoxes()
                    
                    // セッション開始
                    try await arKitSession.run([sceneReconstruction, handTracking])
                } catch {
                    print("ERROR: \(error)")
                }
            }
        } update: { content in }
        .task {
            for await update in sceneReconstruction.anchorUpdates {
                await updateMesh(update.anchor)
            }
        }
        .task {
            for await update in handTracking.anchorUpdates {
                await processHandMovement(update.anchor)
            }
        }
    }
    
    // ----------------------------------------------------------------
    // ★ ハテナボックス（パーティクルあり）
    // ----------------------------------------------------------------
    func createQuestionBox() {
        // ボックス自体の作成 (50cm)
        let mesh = MeshResource.generateBox(size: 0.5)
        var material = SimpleMaterial(color: .yellow, isMetallic: false)
        
        // Assetsに「❓」画像があれば使う
        if let texture = try? TextureResource.load(named: "❓") {
            material.color = .init(texture: .init(texture))
        }
        
        let box = ModelEntity(mesh: mesh, materials: [material])
        // 目の前 1.5m, 高さ 1.5m に配置
        box.position = [0, 1.5, -1.5]
        
        // --- パーティクル設定 ---
        var particles = ParticleEmitterComponent()
        
        // 生成した星テクスチャを適用
        if let tex = generatedStarTexture {
            particles.mainEmitter.image = tex
        }
        
        // ★重要：背景は透明処理済みなので、通常合成(.alpha)できれいに見えます
        particles.mainEmitter.blendMode = .alpha
        
        // 形と場所
        particles.emitterShape = .box
        particles.birthLocation = .surface
        
        // 初期状態では出さない（叩くと出る）
        particles.mainEmitter.birthRate = 0
        
        // ★動きの設定（エラーになるプロパティは排除し、基本機能だけでランダムさを出す）
        particles.mainEmitter.lifeSpan = 2.5
        particles.speed = 0.8
        particles.mainEmitter.size = 0.16
        
        // 全方向に飛び散らせる（これがランダムの肝）
        particles.mainEmitter.spreadingAngle = .pi
        
        // 色：黄色から白へ変化
        let goldColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        particles.mainEmitter.color = .evolving(start: .single(goldColor), end: .single(.white))
        
        box.components.set(particles)
        
        rootEntity.addChild(box)
        self.questionBoxEntity = box
    }
    
    // ----------------------------------------------------------------
    // ★ レンガブロック（パーティクルなし）x 3
    // ----------------------------------------------------------------
    func createBrickBoxes() {
        let mesh = MeshResource.generateBox(size: 0.5)
        var material = SimpleMaterial(color: .brown, isMetallic: false)
        
        // Assetsに「ブロック」画像があれば使う
        if let texture = try? TextureResource.load(named: "ブロック") {
            material.color = .init(texture: .init(texture))
        }
        
        // 3つの配置座標（ハテナボックスの周り）
        let positions: [SIMD3<Float>] = [
            [-0.6, 1.5, -1.5], // 左
            [ 0.6, 1.5, -1.5], // 右
            [ 0.0, 2.1, -1.5]  // 上
        ]
        
        for pos in positions {
            let brickBox = ModelEntity(mesh: mesh, materials: [material])
            brickBox.position = pos
            rootEntity.addChild(brickBox)
        }
    }
    
    // ----------------------------------------------------------------
    // ★ 完璧な星テクスチャ生成（黒い四角回避の切り札）
    // ----------------------------------------------------------------
    func generatePerfectStarTexture() -> TextureResource? {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // 1. 背景を完全に透明にする（ここが重要）
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            
            // 2. 星のパスを描画
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath()
            let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
            let numberOfPoints = 5
            let outerRadius = rect.width / 2 * 0.9
            let innerRadius = outerRadius * 0.4
            let angleIncrement = CGFloat.pi * 2 / CGFloat(numberOfPoints * 2)
            var angle = -CGFloat.pi / 2
            
            for i in 0..<(numberOfPoints * 2) {
                let radius = i % 2 == 0 ? outerRadius : innerRadius
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                angle += angleIncrement
            }
            path.close()
            
            // 3. 色塗り
            UIColor.yellow.setFill()
            path.fill()
            
            // 4. フチ取り（黒）
            UIColor.black.setStroke()
            path.lineWidth = 15
            path.stroke()
            
            // 5. 目を描く（マリオスター風）
            let eyeColor = UIColor.black
            let eyeWidth = size.width * 0.06
            let eyeHeight = size.height * 0.18
            
            let leftEye = UIBezierPath(ovalIn: CGRect(x: size.width * 0.40, y: size.height * 0.35, width: eyeWidth, height: eyeHeight))
            let rightEye = UIBezierPath(ovalIn: CGRect(x: size.width * 0.60, y: size.height * 0.35, width: eyeWidth, height: eyeHeight))
            
            eyeColor.setFill()
            leftEye.fill()
            rightEye.fill()
        }
        
        // RealityKitで使えるテクスチャリソースに変換
        return try? TextureResource.generate(from: image.cgImage!, options: .init(semantic: .color))
    }

    // ----------------------------------------------------------------
    // 更新処理
    // ----------------------------------------------------------------

    @MainActor
    func updateMesh(_ anchor: MeshAnchor) async {
        if let entity = meshEntities[anchor.id] {
            entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
            return
        }
        guard let meshResource = generateMeshResource(from: anchor) else { return }
        
        var materials: [RealityKit.Material] = []
        if let mat = superStarMaterial { materials = [mat] }
        else {
            var t = SimpleMaterial(color: .cyan.withAlphaComponent(0.1), isMetallic: true); t.roughness=0.1
            materials = [t]
        }
        
        let entity = ModelEntity(mesh: meshResource, materials: materials)
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        // 壁の不透明度（薄くする）
        entity.components.set(OpacityComponent(opacity: 0.25))
        
        rootEntity.addChild(entity)
        meshEntities[anchor.id] = entity
    }
    
    @MainActor
    func processHandMovement(_ anchor: HandAnchor) async {
        guard let wrist = anchor.handSkeleton?.joint(.wrist) else { return }
        let currentPos = (anchor.originFromAnchorTransform * wrist.anchorFromJointTransform).translation
        var speed: Float = 0.0
        if anchor.chirality == .left {
            if let lastPos = lastLeftHandPos { speed = distance(currentPos, lastPos) }
            lastLeftHandPos = currentPos
        } else {
            if let lastPos = lastRightHandPos { speed = distance(currentPos, lastPos) }
            lastRightHandPos = currentPos
        }
        
        let targetIntensity = mapSpeedToIntensity(speed, minSpeed: 0.005, maxSpeed: 0.15)
        let lerpFactor: Float = targetIntensity > currentIntensity ? 0.3 : 0.05
        currentIntensity = Checkle.lerp(currentIntensity, targetIntensity, lerpFactor)
        updateEffects(currentIntensity)
    }
    
    func updateEffects(_ intensity: Float) {
        // 1. 壁のマテリアル更新
        for entity in meshEntities.values {
            if var material = entity.model?.materials.first as? ShaderGraphMaterial {
                do {
                    try material.setParameter(name: "Intensity", value: .float(intensity * 5.0))
                    entity.model?.materials[0] = material
                } catch { }
            }
        }
        
        // 2. ハテナボックスのパーティクル更新
        if let box = questionBoxEntity, var particles = box.components[ParticleEmitterComponent.self] {
            // 量をコントロール（最大75個/秒）
            particles.mainEmitter.birthRate = intensity * 75
            
            if intensity > 0.8 {
                particles.mainEmitter.color = .evolving(start: .single(.yellow), end: .single(.cyan))
            } else {
                let goldColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
                particles.mainEmitter.color = .evolving(start: .single(goldColor), end: .single(.white))
            }
            box.components.set(particles)
        }
    }

    // 補助関数
    func mapSpeedToIntensity(_ speed: Float, minSpeed: Float, maxSpeed: Float) -> Float {
        if speed < minSpeed { return 0.0 }
        if speed > maxSpeed { return 1.0 }
        return (speed - minSpeed) / (maxSpeed - minSpeed)
    }
    
    func generateMeshResource(from anchor: MeshAnchor) -> MeshResource? {
        let geometry = anchor.geometry
        let vertices = geometry.vertices.asFloat3()
        let indices = geometry.faces.toUInt32Array()
        var descriptor = MeshDescriptor(name: "SkeletonMesh")
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(indices)
        let scale: Float = 0.18
        let texCoords = vertices.map { vertex in SIMD2<Float>(vertex.x + vertex.z, vertex.y) * scale }
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(texCoords)
        return try? MeshResource.generate(from: [descriptor])
    }
    
    struct Checkle {
        static func lerp(_ start: Float, _ end: Float, _ t: Float) -> Float {
            return start + (end - start) * t
        }
    }
} // ★ImmersiveView終了

// ----------------------------------------------------------------
// 5. 拡張機能 (ImmersiveViewの外側)
// ----------------------------------------------------------------

extension matrix_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension GeometrySource {
    func asFloat3() -> [SIMD3<Float>] {
        return (0..<self.count).map {
            self.buffer.contents().advanced(by: self.offset + self.stride * Int($0))
                .assumingMemoryBound(to: SIMD3<Float>.self).pointee
        }
    }
}

extension GeometryElement {
    func toUInt32Array() -> [UInt32] {
        let buffer = self.buffer.contents()
        let count = self.count * 3
        if self.bytesPerIndex == 2 {
            let pointer = buffer.assumingMemoryBound(to: UInt16.self)
            return (0..<count).map { UInt32(pointer[Int($0)]) }
        } else {
            let pointer = buffer.assumingMemoryBound(to: UInt32.self)
            return (0..<count).map { pointer[Int($0)] }
        }
    }
}
