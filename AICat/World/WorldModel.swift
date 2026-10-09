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
    private(set) var cat: any CatRig
    let camera = CameraRig()
    let lighting = Lighting()

    @ObservationIgnored private var subscription: EventSubscription?
    @ObservationIgnored private var built = false
    @ObservationIgnored private var props: [String: Entity] = [:]
    @ObservationIgnored private(set) var posture: StagePosture = .pocket
    @ObservationIgnored private(set) var openness: Double = 1
    @ObservationIgnored private(set) var reduceEffects = false
    /// Called every frame with the delta time (challenge logic hooks in here).
    @ObservationIgnored var onFrame: ((Float) -> Void)?
    @ObservationIgnored private var lastGrowth: Double = -1
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var attachGeneration = 0
    @ObservationIgnored private var sky: EnvironmentResource?

    init(theme: WorldTheme) {
        self.theme = theme
        cat = ProceduralCatRig()
        root.name = "world"
        propsRoot.name = "props"
    }

    /// One-time asynchronous work: a bundled USDZ cat (if any) and the procedural sky used for the skybox
    /// and image-based lighting. Safe to call many times.
    func prepare() async {
        if let preparation {
            await preparation.value   // a second RealityView waits for the same work
            return
        }
        let task = Task { @MainActor in
            await self.runPreparation()
        }
        preparation = task
        await task.value
    }

    private func runPreparation() async {
        async let usdz = USDZCatRig.load()
        async let skyResource = SkyEnvironment.resource(for: theme)
        await TextureLibrary.shared.prepare(TextureLibrary.kinds(for: theme))
        if let loaded = await usdz {
            cat = loaded
        }
        sky = await skyResource
    }

    /// Call from a RealityView's make closure before `prepare()`; pass the token to `attach` so a view
    /// that was replaced while preparing (posture change) never steals the scene from the live one.
    func beginAttach() -> Int {
        attachGeneration += 1
        return attachGeneration
    }

    private func buildIfNeeded() {
        guard !built else { return }
        built = true
        root.addChild(lighting.root)
        root.addChild(camera.entity)
        SceneBuilder.build(theme: theme, into: root)
        root.addChild(propsRoot)
        if cat.root.position == .zero {
            cat.root.position = [0, 0, 0.2]   // default spot unless a controller already placed the cat
        }
        root.addChild(cat.root)
        cat.apply(morphology: cat.morphology, animated: false)   // rebuilds the coat with the textures now cached
        lighting.setTheme(skyTint: UIColor(Theme.palette(for: theme).sky))
        camera.applyPosture(posture)
        if let sky {
            root.components.set(ImageBasedLightComponent(source: .single(sky)))
            applyLightReceivers(to: root)
        }
    }

    private func applyLightReceivers(to entity: Entity) {
        if entity is ModelEntity {
            entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: root))
        }
        for child in entity.children {
            applyLightReceivers(to: child)
        }
    }

    /// Attach the graph to a (possibly new) RealityView content and start ticking.
    func attach(to content: inout RealityViewCameraContent, generation: Int? = nil) {
        if let generation, generation != attachGeneration { return }
        buildIfNeeded()
        if SmokeMode.isActive {
            let kinds = TextureLibrary.kinds(for: theme)
            SmokeMode.worldAttached(self, theme: theme, textures: TextureLibrary.shared.cachedCount(of: kinds), expected: Set(kinds).count, sky: sky != nil, usdz: cat is USDZCatRig)
        }
        root.removeFromParent()
        content.add(root)
        if let sky {
            content.environment = .skybox(sky)
        }
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(Float(event.deltaTime))
        }
    }

    func celebrate() {
        guard !reduceEffects else { return }
        Celebration.burst(in: self)
    }

    private func tick(_ rawDelta: Float) {
        let dt = min(max(rawDelta, 0), 1.0 / 20.0)
        cat.update(deltaTime: dt, cameraPosition: camera.position)
        camera.subjectHeight = Float(cat.morphology.standingHeight)
        camera.update(target: cat.chestPosition, deltaTime: dt)
        onFrame?(dt)
        SmokeMode.frame(self)
    }

    // MARK: Cat

    func setGrowth(_ growth: Double, animated: Bool) {
        guard abs(growth - lastGrowth) > 1e-9 else { return }
        let first = lastGrowth < 0
        lastGrowth = growth
        cat.apply(morphology: CatMorphology.interpolated(growth: growth), animated: animated && !first)
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
        let changedFold = posture.isFolded != self.posture.isFolded
        self.posture = posture
        camera.applyPosture(posture)
        if changedFold, !reduceEffects {
            cat.play(gesture: .headTilt)
        }
    }

    /// Mirrors the parent-zone / system "reduce motion" preference: no sunrise, no particles, no gestures on fold.
    func setReduceEffects(_ reduce: Bool) {
        reduceEffects = reduce
        if reduce { lighting.setOpenness(1) }
    }

    func setOpenness(_ openness: Double) {
        self.openness = openness
        guard !reduceEffects else { return }
        lighting.setOpenness(openness)
    }

    // MARK: Props

    @discardableResult
    func addProp(_ entity: Entity, id: String) -> Entity {
        removeProp(id: id)
        entity.name = id
        props[id] = entity
        propsRoot.addChild(entity)
        if sky != nil {
            applyLightReceivers(to: entity)
        }
        return entity
    }

    func prop(id: String) -> Entity? {
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
