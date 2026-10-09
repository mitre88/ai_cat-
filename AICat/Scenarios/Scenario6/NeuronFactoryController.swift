import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Neuron Factory challenge: dial-neurons the child sets by hand (levels 1–3) or a sigmoid
/// network that trains itself while the child picks the learning speed (master level).
@MainActor
@Observable
final class NeuronFactoryController {
    let spec: ChallengeSpec
    private(set) var dials: NeuronChallenge?
    private(set) var training: TrainingChallenge?
    private(set) var selectedExample = 0
    private(set) var isDone = false
    private(set) var hintsLeft: Int
    private(set) var lastHint: NeuronDial?
    private(set) var lastLosses: [Double] = []
    let trainingTarget: NeuronContent.TrainingTarget?

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var blink: Float = 0

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 15_485_863 &+ UInt64(spec.index) &* 17
        if spec.param("autoTrain", default: 0) == 1 {
            training = NeuronContent.makeTraining(spec: spec, difficulty: app.profile.difficulty, seed: seed)
            trainingTarget = NeuronContent.trainingTarget(seed: seed)
        } else {
            dials = NeuronContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
            trainingTarget = nil
        }
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived state

    var isTrainingMode: Bool { training != nil }
    var examples: [NeuronExample] { dials?.examples ?? training?.examples ?? [] }
    var inputCount: Int { examples.first?.inputs.count ?? 2 }
    var network: TernaryNetwork? { dials?.network }
    var hiddenCount: Int { dials?.network.hidden.count ?? training?.hiddenCount ?? 0 }
    var correctCount: Int { dials?.correctCount ?? training?.correctCount ?? 0 }
    var isSolved: Bool { dials?.isSolved ?? training?.isSolved ?? false }
    var canRequestHint: Bool { dials != nil && hintsLeft > 0 && !isDone }
    var trainingTargetKey: String? { trainingTarget?.key }
    var currentExample: NeuronExample? { examples.indices.contains(selectedExample) ? examples[selectedExample] : nil }

    func prediction(for example: NeuronExample) -> Int {
        if let dials { return dials.network.predict(example.inputs) }
        if let training { return training.network.predict(example.inputs) }
        return 0
    }

    func outputProbability(for example: NeuronExample) -> Double {
        training?.network.forward(example.inputs).output ?? Double(prediction(for: example))
    }

    func hiddenActivations(for example: NeuronExample) -> [Double] {
        if let dials { return dials.network.hiddenActivations(example.inputs).map(Double.init) }
        if let training { return training.network.forward(example.inputs).hidden }
        return []
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.5, 0, 0.15]
        world.cat.stopWalking()
        let pedestal = PropFactory.pedestal(color: Color(red: 0.5, green: 0.5, blue: 0.58), radius: 0.36)
        pedestal.position = [-0.45, 0, 0.3]
        world.addProp(pedestal, id: "machine")
        let column = ModelEntity(mesh: .generateBox(size: [0.06, 0.5, 0.06], cornerRadius: 0.01), materials: [Materials.metal(Color(red: 0.4, green: 0.4, blue: 0.46))])
        column.position = [-0.45, 0.35, 0.3]
        world.addProp(column, id: "column")
        for i in 0..<inputCount {
            let lamp = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [Materials.matte(Self.lampOff)])
            lamp.position = [-0.45 + (Float(i) - Float(inputCount - 1) / 2) * 0.14, 0.17, 0.42]
            lamp.components.set(GroundingShadowComponent(castsShadow: true))
            world.addProp(lamp, id: "input_\(i)")
        }
        for j in 0..<hiddenCount {
            let lamp = ModelEntity(mesh: .generateSphere(radius: 0.04), materials: [Materials.matte(Self.lampOff)])
            lamp.position = [-0.45 + (Float(j) - Float(hiddenCount - 1) / 2) * 0.14, 0.38, 0.34]
            world.addProp(lamp, id: "hidden_\(j)")
        }
        let output = ModelEntity(mesh: .generateSphere(radius: 0.075), materials: [Materials.matte(Self.lampOff)])
        output.position = [-0.45, 0.64, 0.3]
        world.addProp(output, id: "output")
        world.cat.lookAt([-0.45, 0.64, 0.3])
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        refreshLamps()
        updateProgress()
    }

    static let lampOff = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let lampOn = Color(red: 1.0, green: 0.85, blue: 0.3)
    static let hiddenOn = Color(red: 0.4, green: 0.8, blue: 1.0)

    private func setLamp(_ id: String, on: Double, color: Color) {
        guard let lamp = world.prop(id: id) as? ModelEntity else { return }
        lamp.model?.materials = [on > 0.05 ? Materials.glowing(color, intensity: Float(0.3 + 1.4 * on)) : Materials.matte(Self.lampOff)]
    }

    /// Lights the stage lamps for the selected example.
    private func refreshLamps() {
        guard let example = currentExample else { return }
        for (i, value) in example.inputs.enumerated() {
            setLamp("input_\(i)", on: Double(value), color: Self.lampOn)
        }
        for (j, value) in hiddenActivations(for: example).enumerated() {
            setLamp("hidden_\(j)", on: value, color: Self.hiddenOn)
        }
        setLamp("output", on: outputProbability(for: example), color: Self.lampOn)
    }

    private func frame(_ dt: Float) {
        if isDone {
            blink += dt
            let pulse = Double(0.5 + 0.5 * sin(blink * 6))
            setLamp("output", on: pulse, color: Self.lampOn)
        }
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: dials?.scoreAccuracy ?? training?.scoreAccuracy ?? 0, app: app)
        } else {
            finishCountdown = next
        }
    }

    private func updateProgress() {
        guard !isSolved else {
            session.progress = 1
            return
        }
        let total = max(examples.count, 1)
        session.progress = min(0.9, Double(correctCount) / Double(total))
    }

    // MARK: Board actions

    func select(example index: Int) {
        guard examples.indices.contains(index) else { return }
        selectedExample = index
        refreshLamps()
    }

    func cycleWeight(_ dial: NeuronDial) {
        guard !isDone, dials != nil else { return }
        dials?.cycleWeight(dial)
        lastHint = nil
        react()
    }

    func adjustThreshold(_ dial: NeuronDial, by delta: Int) {
        guard !isDone, dials != nil else { return }
        dials?.adjustThreshold(dial, by: delta)
        lastHint = nil
        react()
    }

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        session.noteHint()
        if let dial = dials?.hint() {
            lastHint = dial
            app.say(.hint)
        } else {
            app.say(.aiNeedsMore)
        }
        react()
    }

    func selectRate(_ index: Int) {
        guard !isDone else { return }
        training?.selectRate(index)
    }

    func train() {
        guard !isDone, training != nil else { return }
        lastLosses = training?.train() ?? []
        world.cat.play(gesture: .headTilt)
        react()
    }

    func restart() {
        guard !isDone, training != nil else { return }
        training?.restart()
        lastLosses = []
        app.say(.encouragement)
        react()
    }

    private func react() {
        refreshLamps()
        updateProgress()
        if isSolved {
            isDone = true
            session.progress = 1
            world.cat.set(emotion: .proud)
            world.cat.play(gesture: .jump)
            world.celebrate()
            app.say(.aiLearned)
            finishCountdown = 2.0
        } else if Double(correctCount) / Double(max(examples.count, 1)) >= 0.75 {
            world.cat.set(emotion: .curious)
        } else {
            world.cat.set(emotion: .thinking)
        }
    }
}
