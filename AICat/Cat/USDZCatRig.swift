import RealityKit
import simd
import AICatCore

/// Slot for a professional model: drop `AICat.usdz` into `AICat/Resources` and it replaces the procedural
/// kitten (see Docs/ART_PIPELINE.md). Growth = uniform scale to the morphology's standing height;
/// the model's first animation loops; gestures and gaze are best effort.
@MainActor
final class USDZCatRig: CatRig {
    static let resourceName = "AICat"

    let root = Entity()
    private(set) var morphology: Morphology = .kitten
    private(set) var emotion: CatEmotion = .happy
    private let model: Entity
    private let baseHeight: Float
    private var walkCompletion: (() -> Void)?
    private var walkDeadline: Float = 0

    static var isBundled: Bool {
        Bundle.main.url(forResource: resourceName, withExtension: "usdz") != nil
    }

    static func load() async -> USDZCatRig? {
        guard isBundled, let entity = try? await Entity(named: resourceName, in: nil) else { return nil }
        return USDZCatRig(model: entity)
    }

    private init(model: Entity) {
        self.model = model
        let bounds = model.visualBounds(relativeTo: nil)
        baseHeight = max(bounds.extents.y, 0.01)
        root.name = "aiCat-usdz"
        root.addChild(model)
        if let animation = model.availableAnimations.first {
            model.playAnimation(animation.repeat(), transitionDuration: 0.3, startsPaused: false)
        }
        apply(morphology: .kitten, animated: false)
    }

    func apply(morphology: Morphology, animated: Bool) {
        self.morphology = morphology
        let scale = Float(morphology.standingHeight) / baseHeight
        if animated {
            root.move(to: Transform(scale: SIMD3<Float>(repeating: scale), rotation: root.orientation, translation: root.position), relativeTo: root.parent, duration: 0.9, timingFunction: .easeInOut)
        } else {
            root.scale = SIMD3<Float>(repeating: scale)
        }
    }

    func set(emotion: CatEmotion) {
        self.emotion = emotion
    }

    func play(gesture: CatGesture) {
        guard gesture == .jump || gesture == .pounce else { return }
        let up = Transform(scale: root.scale, rotation: root.orientation, translation: root.position + [0, Float(morphology.bodyLength) * 0.5, 0])
        root.move(to: up, relativeTo: root.parent, duration: 0.25, timingFunction: .easeOut)
        let down = Transform(scale: root.scale, rotation: root.orientation, translation: root.position)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 260_000_000)
            self?.root.move(to: down, relativeTo: self?.root.parent, duration: 0.25, timingFunction: .easeIn)
        }
    }

    func lookAt(_ point: SIMD3<Float>?) {}

    func walk(to point: SIMD3<Float>, completion: (() -> Void)?) {
        let delta = point - root.position
        let distance = simd_length(SIMD3<Float>(delta.x, 0, delta.z))
        let yaw = atan2(delta.x, delta.z)
        let duration = Double(distance / max(Float(morphology.bodyLength) * 1.6, 0.05))
        let transform = Transform(scale: root.scale, rotation: simd_quatf(angle: yaw, axis: [0, 1, 0]), translation: [point.x, 0, point.z])
        root.move(to: transform, relativeTo: root.parent, duration: duration, timingFunction: .easeInOut)
        walkCompletion = completion
        walkDeadline = Float(duration)
    }

    func stopWalking() {
        walkCompletion = nil
        walkDeadline = 0
    }

    func wear(_ items: [KnowledgeItem]) {}

    func update(deltaTime: Float, cameraPosition: SIMD3<Float>) {
        guard walkCompletion != nil else { return }
        walkDeadline -= deltaTime
        if walkDeadline <= 0 {
            let completion = walkCompletion
            walkCompletion = nil
            completion?()
        }
    }

    var chestPosition: SIMD3<Float> {
        root.position + SIMD3<Float>(0, Float(morphology.standingHeight) * 0.5, 0)
    }

    var headPosition: SIMD3<Float> {
        root.position + SIMD3<Float>(0, Float(morphology.standingHeight) * 0.85, 0)
    }
}
