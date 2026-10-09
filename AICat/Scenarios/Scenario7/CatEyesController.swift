import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one AI CAT's Eyes challenge: pixels, edges, shape matching, or live checks with the camera.
/// The picture is also built on stage as a grid of little cubes that light up with the child's actions.
@MainActor
@Observable
final class CatEyesController {
    enum Level: Equatable {
        case pixels, edges, shapes, live
    }

    enum CameraState: Equatable {
        case needsParent, idle, starting, running, samples
    }

    let spec: ChallengeSpec
    let level: Level
    private(set) var pixels: PixelChallenge?
    private(set) var edges: EdgeChallenge?
    private(set) var shapes: ShapeMatchChallenge?
    private(set) var live: LiveCheckChallenge?
    private(set) var isDone = false
    private(set) var hintsLeft: Int
    private(set) var hintPoint: PixelPoint?
    private(set) var lastPickCorrect: Bool?
    private(set) var zoomNotice = false
    private(set) var hintRound: Int?

    // Live level
    let camera = CameraClassifier()
    private(set) var cameraState: CameraState = .needsParent
    private(set) var cameraDenied = false
    private(set) var sampleIndex = 0
    private(set) var sampleGuesses: [CameraClassifier.Guess] = []
    private(set) var isClassifying = false
    static let samples = ["🍎", "🚲", "🐶", "☕️", "🌻", "📚", "⚽️", "🚗"]

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 2_654_435_761 &+ UInt64(spec.index) &* 19
        let difficulty = app.profile.difficulty
        if spec.param("live", default: 0) == 1 {
            level = .live
            live = VisionContent.makeLive(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("objects", default: 0) == 1 {
            level = .shapes
            shapes = VisionContent.makeShapes(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("edges", default: 0) == 1 {
            level = .edges
            edges = VisionContent.makeEdges(spec: spec, difficulty: difficulty, seed: seed)
        } else {
            level = .pixels
            pixels = VisionContent.makePixels(spec: spec, difficulty: difficulty, seed: seed)
        }
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived

    var isSolved: Bool {
        pixels?.isSolved ?? edges?.isSolved ?? shapes?.isSolved ?? live?.isSolved ?? false
    }

    var canConfirm: Bool { !isDone && isSolved }
    var canRequestHint: Bool { hintsLeft > 0 && !isDone && !isSolved && level != .live }
    var currentGuesses: [CameraClassifier.Guess] { cameraState == .running ? camera.guesses : sampleGuesses }
    var currentSample: String { Self.samples[sampleIndex % Self.samples.count] }

    private var scoreAccuracy: Double {
        pixels?.scoreAccuracy ?? edges?.scoreAccuracy ?? shapes?.scoreAccuracy ?? live?.scoreAccuracy ?? 0
    }

    /// The picture currently shown on stage.
    private var stageImage: PixelImage? {
        if let pixels { return pixels.image }
        if let edges { return edges.image }
        if let shapes { return shapes.current?.query ?? shapes.rounds.last?.query }
        return nil
    }

    // MARK: Stage

    static let cube: Float = 0.055

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.5, 0, 0.2]
        world.cat.stopWalking()
        let base = PropFactory.pedestal(color: Color(red: 0.45, green: 0.5, blue: 0.6), radius: 0.38)
        base.position = [-0.4, 0, 0.3]
        world.addProp(base, id: "lookout")
        if let image = stageImage {
            for point in image.allPoints {
                let cube = ModelEntity(mesh: .generateBox(size: [Self.cube * 0.9, Self.cube * 0.9, Self.cube * 0.9], cornerRadius: 0.004),
                                       materials: [Materials.matte(Self.grey(image[point]))])
                cube.position = cubePosition(point, image: image)
                world.addProp(cube, id: Self.cubeID(point))
            }
            world.cat.lookAt([-0.4, 0.45, 0.3])
        } else {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [Materials.glossy(Color(red: 0.2, green: 0.8, blue: 0.7))])
            eye.position = [-0.4, 0.35, 0.3]
            eye.components.set(GroundingShadowComponent(castsShadow: true))
            world.addProp(eye, id: "eye")
            world.cat.lookAt([-0.4, 0.35, 0.3])
        }
        refreshStage()
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private static func cubeID(_ point: PixelPoint) -> String { "px_\(point.x)_\(point.y)" }

    private func cubePosition(_ point: PixelPoint, image: PixelImage) -> SIMD3<Float> {
        let x = -0.4 + (Float(point.x) - Float(image.width - 1) / 2) * Self.cube
        let y = 0.14 + (Float(image.height - 1 - point.y) + 0.5) * Self.cube
        return [x, y, 0.3]
    }

    static func grey(_ value: Int) -> Color {
        let v = Double(max(0, min(9, value))) / 9
        return Color(red: 0.12 + 0.86 * v, green: 0.12 + 0.86 * v, blue: 0.16 + 0.82 * v)
    }

    /// Repaints the cubes: picked bright pixels glow, detected edges turn orange, the query shows as is.
    private func refreshStage() {
        guard let image = stageImage else { return }
        var highlight: Set<PixelPoint> = []
        var highlightColor = Color.orange
        if let pixels {
            highlight = pixels.picks.intersection(pixels.targets)
            highlightColor = Color.yellow
        } else if let edges {
            highlight = edges.edges
        }
        for point in image.allPoints {
            guard let cube = world.prop(id: Self.cubeID(point)) as? ModelEntity else { continue }
            cube.position = cubePosition(point, image: image)
            cube.model?.materials = [highlight.contains(point) ? Materials.glowing(highlightColor, intensity: 1.3) : Materials.matte(Self.grey(image[point]))]
        }
    }

    private func frame(_ dt: Float) {
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: scoreAccuracy, app: app)
        } else {
            finishCountdown = next
        }
    }

    private func updateProgress() {
        if let pixels { session.progress = 1 - Double(pixels.remaining) / Double(max(pixels.targets.count, 1)) }
        if let edges { session.progress = min(1, edges.f1 / EdgeChallenge.targetF1) }
        if let shapes { session.progress = Double(shapes.answers.count) / Double(max(shapes.rounds.count, 1)) }
        if let live { session.progress = Double(live.checks.count) / Double(live.required) }
    }

    private func react() {
        updateProgress()
        refreshStage()
        world.cat.set(emotion: isSolved ? .proud : .curious)
    }

    // MARK: Pixels

    func setZoom(_ level: Int) {
        guard !isDone, pixels != nil else { return }
        pixels?.setZoom(level)
        zoomNotice = false
    }

    func tapPixel(_ point: PixelPoint) {
        guard !isDone, var challenge = pixels else { return }
        guard challenge.zoom == PixelChallenge.maxZoom else {
            zoomNotice = true
            return
        }
        let before = challenge.picks.count
        let right = challenge.tap(point)
        pixels = challenge
        hintPoint = nil
        if challenge.picks.count > before {
            if right {
                world.cat.play(gesture: .nod)
                app.say(challenge.isSolved ? .aiLearned : .correct)
            } else {
                world.cat.play(gesture: .headTilt)
                app.say(.wrong)
            }
        }
        react()
    }

    // MARK: Edges

    func adjustThreshold(by delta: Int) {
        guard !isDone, var challenge = edges else { return }
        challenge.setThreshold(challenge.threshold + delta)
        edges = challenge
        if challenge.isSolved { app.say(.aiLearned) }
        react()
    }

    // MARK: Shapes

    func pickShape(_ templateID: String) {
        guard !isDone, var challenge = shapes else { return }
        guard let right = challenge.pick(templateID) else { return }
        shapes = challenge
        lastPickCorrect = right
        if right {
            world.cat.play(gesture: .nod)
            app.say(.correct)
        } else {
            world.cat.play(gesture: .headTilt)
            app.say(.encouragement)
        }
        react()
    }

    // MARK: Live

    func approveParent() {
        guard cameraState == .needsParent else { return }
        cameraState = .idle
    }

    func openEyes() {
        guard cameraState == .idle else { return }
        guard CameraClassifier.isSupported else {
            useSamples()
            return
        }
        cameraState = .starting
        Task { [weak self] in
            guard let self else { return }
            await self.camera.start()
            if self.camera.isRunning {
                self.cameraState = .running
                self.world.cat.set(emotion: .curious)
            } else {
                self.cameraDenied = self.camera.isDenied
                self.useSamples()
            }
        }
    }

    func useSamples() {
        cameraState = .samples
        classifyCurrentSample()
    }

    func nextSample() {
        guard cameraState == .samples else { return }
        sampleIndex += 1
        classifyCurrentSample()
    }

    private func classifyCurrentSample() {
        isClassifying = true
        let emoji = currentSample
        Task { [weak self] in
            guard let self else { return }
            var guesses = await CameraClassifier.classifySample(emoji: emoji)
            if guesses.isEmpty {
                guesses = [CameraClassifier.Guess(id: "unknown", label: L10n.string("vision.live.unknown"), confidence: 0.1)]
            }
            self.sampleGuesses = guesses
            self.isClassifying = false
        }
    }

    func check(_ guess: CameraClassifier.Guess, agreed: Bool) {
        guard !isDone, var challenge = live else { return }
        challenge.record(label: guess.label, confidence: guess.confidence, agreed: agreed)
        live = challenge
        world.cat.play(gesture: agreed ? .nod : .headTilt)
        app.say(agreed ? .correct : .encouragement)
        if cameraState == .samples {
            sampleIndex += 1
            classifyCurrentSample()
        }
        react()
        if challenge.isSolved { confirm() }
    }

    func stopCamera() {
        camera.stop()
        if cameraState == .running { cameraState = .idle }
    }

    // MARK: Hints and finishing

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        session.noteHint()
        app.say(.hint)
        if let pixels {
            hintPoint = pixels.targets.subtracting(pixels.picks).first
            self.pixels?.setZoom(PixelChallenge.maxZoom)
        } else if var challenge = edges {
            challenge.setThreshold(challenge.threshold < 4 ? challenge.threshold + 1 : challenge.threshold - 1)
            edges = challenge
        } else if let shapes, shapes.current != nil {
            hintRound = shapes.currentIndex
        }
        react()
    }

    /// The template with the most clues, shown only for the round the hint was asked in.
    var hintedShapeID: String? {
        guard let shapes, let round = shapes.current, hintRound == shapes.currentIndex else { return nil }
        return round.clues.max { $0.value < $1.value }?.key
    }

    func confirm() {
        guard canConfirm else { return }
        isDone = true
        session.progress = 1
        stopCamera()
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        app.say(.aiSorted)
        finishCountdown = 1.8
    }
}
