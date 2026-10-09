import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Classifier Workshop challenge: the child shapes a classifier (threshold, line or centroids)
/// on the 2-D board; AI CAT's "machine" on stage lights up when the groups are separated.
@MainActor
@Observable
final class ClassifierWorkshopController {
    let spec: ChallengeSpec
    private(set) var challenge: ScatterChallenge
    private(set) var isDone = false
    private(set) var hintsLeft: Int
    private(set) var reachedTargetOnce = false

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false

    static let classColors: [Color] = [DataLibraryController.color(for: .cat), DataLibraryController.color(for: .dog), DataLibraryController.color(for: .bird)]

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 6_700_417 &+ UInt64(spec.index) &* 29
        challenge = ScatterContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    static func species(for label: Int) -> Species {
        Species.allCases[((label % 3) + 3) % 3]
    }

    static func color(for label: Int) -> Color {
        classColors[((label % 3) + 3) % 3]
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.45, 0, 0.1]
        world.cat.stopWalking()
        let pedestal = PropFactory.pedestal(color: Color(red: 0.55, green: 0.55, blue: 0.6), radius: 0.32)
        pedestal.position = [-0.5, 0, 0.35]
        world.addProp(pedestal, id: "machine")
        for label in 0..<challenge.classes {
            let orb = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [Materials.matte(Self.color(for: label))])
            orb.position = [-0.5 + Float(label - 1) * 0.18, 0.13, 0.35]
            orb.components.set(GroundingShadowComponent(castsShadow: true))
            world.addProp(orb, id: "orb_\(label)")
        }
        world.cat.lookAt([-0.5, 0.15, 0.35])
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private func frame(_ dt: Float) {
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: challenge.scoreAccuracy, app: app)
        } else {
            finishCountdown = next
        }
    }

    // MARK: Board actions

    var accuracy: Double { challenge.accuracy }
    var isSolved: Bool { challenge.isSolved }

    func setThreshold(_ x: Double) {
        guard !isDone else { return }
        challenge.setThreshold(x)
        react()
    }

    func setLine(x1: Double, y1: Double, x2: Double, y2: Double) {
        guard !isDone else { return }
        challenge.setLine(x1: x1, y1: y1, x2: x2, y2: y2)
        react()
    }

    func moveCentroid(label: Int, x: Double, y: Double) {
        guard !isDone else { return }
        challenge.moveCentroid(label: label, x: x, y: y)
        react()
    }

    func toggleFlag(_ point: ScatterPoint) {
        guard !isDone, challenge.allowsFlagging else { return }
        challenge.toggleFlag(pointID: point.id)
        if challenge.flagged.contains(point.id) && !point.isOutlier {
            app.say(.wrong)
        }
        react()
    }

    private func react() {
        updateProgress()
        let solved = challenge.isSolved
        for label in 0..<challenge.classes {
            if let orb = world.prop(id: "orb_\(label)") as? ModelEntity {
                orb.model?.materials = [solved ? Materials.glowing(Self.color(for: label), intensity: 1.4) : Materials.matte(Self.color(for: label))]
            }
        }
        if solved {
            world.cat.set(emotion: .proud)
            if !reachedTargetOnce {
                reachedTargetOnce = true
                world.cat.play(gesture: .jump)
                app.say(.aiLearned)
            }
        } else if accuracy < 0.6 {
            world.cat.set(emotion: .thinking)
        } else {
            world.cat.set(emotion: .curious)
        }
    }

    private func updateProgress() {
        session.progress = min(challenge.accuracy / challenge.targetAccuracy, 1)
    }

    var canRequestHint: Bool { hintsLeft > 0 && !isDone && !challenge.isSolved }

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        challenge.applyHint()
        session.noteHint()
        app.say(.hint)
        react()
    }

    /// The child is happy with the classifier: show the new animals and finish.
    func confirm() {
        guard challenge.isSolved, !isDone else { return }
        isDone = true
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        app.say(.aiSorted)
        finishCountdown = 2.2
    }
}
