import RealityKit
import Observation
import SwiftUI
import AICatCore

/// Owns the RealityKit scene graph of a world: the set, the lights, the camera, AI CAT and the props.
/// `RealityView` may be recreated when the posture changes; the graph survives here and is re-attached.
@MainActor
@Observable
final class WorldModel {
    let theme: WorldTheme
    let root = Entity()
    let propsRoot = Entity()
    let cat: ProceduralCatRig
    let camera = CameraRig()
    let lighting = Lighting()

    @ObservationIgnored private var subscription: EventSubscription?
    @ObservationIgnored private var built = false
    @ObservationIgnored private var props: [String: ModelEntity] = [:]
    @ObservationIgnored private(set) var posture: StagePosture = .pocket
    @ObservationIgnored private(set) var openness: Double = 1
    /// Called every frame with the delta time (challenge logic hooks in here).
    @ObservationIgnored var onFrame: ((Float) -> Void)?
    @ObservationIgnored private var lastGrowth: Double = -1

    init(theme: WorldTheme) {
        self.theme = theme
        cat = ProceduralCatRig()
        root.name = "world"
        propsRoot.name = "props"
    }

    private func buildIfNeeded() {
        guard !built else { return }
        built = true
        root.addChild(lighting.root)
        root.addChild(camera.entity)
        SceneBuilder.build(theme: theme, into: root)
        root.addChild(propsRoot)
        cat.root.position = [0, 0, 0.2]
        root.addChild(cat.root)
        lighting.setTheme(skyTint: UIColor(Theme.palette(for: theme).sky))
        camera.applyPosture(posture)
    }

    /// Attach the graph to a (possibly new) RealityView content and start ticking.
    func attach(to content: inout RealityViewCameraContent) {
        buildIfNeeded()
        root.removeFromParent()
        content.add(root)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(Float(event.deltaTime))
        }
    }

    private func tick(_ rawDelta: Float) {
        let dt = min(max(rawDelta, 0), 1.0 / 20.0)
        cat.update(deltaTime: dt, cameraPosition: camera.position)
        camera.subjectHeight = Float(cat.morphology.standingHeight)
        camera.update(target: cat.chestPosition, deltaTime: dt)
        onFrame?(dt)
    }

    // MARK: Cat

    func setGrowth(_ growth: Double, animated: Bool) {
        guard abs(growth - lastGrowth) > 1e-9 else { return }
        let first = lastGrowth < 0
        lastGrowth = growth
        cat.apply(morphology: Morphology.interpolated(growth: growth), animated: animated && !first)
    }

    func wear(_ items: [KnowledgeItem]) {
        cat.wear(items)
    }

    func apply(line: CatLine?) {
        guard let line else { return }
        cat.set(emotion: line.emotion)
        cat.play(gesture: line.gesture)
    }

    // MARK: Posture & hinge

    func setPosture(_ posture: StagePosture) {
        self.posture = posture
        camera.applyPosture(posture)
    }

    func setOpenness(_ openness: Double) {
        self.openness = openness
        lighting.setOpenness(openness)
    }

    // MARK: Props

    @discardableResult
    func addProp(_ entity: ModelEntity, id: String) -> ModelEntity {
        removeProp(id: id)
        entity.name = id
        props[id] = entity
        propsRoot.addChild(entity)
        return entity
    }

    func prop(id: String) -> ModelEntity? {
        props[id]
    }

    func removeProp(id: String) {
        if let existing = props.removeValue(forKey: id) {
            existing.removeFromParent()
        }
    }

    func clearProps() {
        for (_, entity) in props { entity.removeFromParent() }
        props.removeAll()
    }

    var propIDs: [String] { Array(props.keys) }
}
