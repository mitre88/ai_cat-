import RealityKit
import AICatCore

/// Anything that can be AI CAT on stage: the procedural kitten today, a USDZ model tomorrow.
@MainActor
protocol CatRig: AnyObject {
    var root: Entity { get }
    var morphology: CatMorphology { get }
    var emotion: CatEmotion { get }
    /// World-space point at the cat's chest, for the camera.
    var chestPosition: SIMD3<Float> { get }
    var headPosition: SIMD3<Float> { get }

    func apply(morphology: CatMorphology, animated: Bool)
    func set(emotion: CatEmotion)
    func play(gesture: CatGesture)
    /// Point of interest the eyes and head follow (world space). nil = look at the camera.
    func lookAt(_ point: SIMD3<Float>?)
    /// Walk to a point on the ground; `completion` runs on arrival.
    func walk(to point: SIMD3<Float>, completion: (() -> Void)?)
    func stopWalking()
    func wear(_ items: [KnowledgeItem])
    func update(deltaTime: Float, cameraPosition: SIMD3<Float>)
}
