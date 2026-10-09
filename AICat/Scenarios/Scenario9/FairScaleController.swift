import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Fair Scale challenge: find the missing group, balance the data set, keep data private,
/// or judge AI decisions. A scale on stage tilts with the fairness gap and levels as the child fixes things.
@MainActor
@Observable
final class FairScaleController {
    enum Level: Equatable {
        case hunt, balance, privacy, judge
    }

    enum Feedback: Equatable {
        case wrongPick
        case rightPick(CatCoat)
    }

    let spec: ChallengeSpec
    let level: Level
    private(set) var hunt: BiasHuntChallenge?
    private(set) var balance: BalanceChallenge?
    private(set) var privacy: PrivacyChallenge?
    private(set) var judge: JudgeChallenge?
    private(set) var isDone = false
    private(set) var feedback: Feedback?
    private(set) var hintsLeft: Int
    private(set) var hintCoat: CatCoat?

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var tilt: Float = 0
    @ObservationIgnored private var targetTilt: Float = 0

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 7_368_787 &+ UInt64(spec.index) &* 23
        let difficulty = app.profile.difficulty
        if spec.param("mistakes", default: 0) == 1 {
            level = .judge
            judge = FairnessContent.makeJudge(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("privacy", default: 0) == 1 {
            level = .privacy
            privacy = FairnessContent.makePrivacy(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("fix", default: 0) == 1 {
            level = .balance
            balance = FairnessContent.makeBalance(spec: spec, difficulty: difficulty, seed: seed)
        } else {
            level = .hunt
            hunt = FairnessContent.makeBiasHunt(spec: spec, difficulty: difficulty, seed: seed)
        }
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived

    var isSolved: Bool {
        hunt?.isSolved ?? balance?.isSolved ?? privacy?.isSolved ?? judge?.isSolved ?? false
    }

    var canConfirm: Bool { !isDone && isSolved }
    var canRequestHint: Bool {
        guard hintsLeft > 0, !isDone else { return false }
        if let privacy { return privacy.correctCount < privacy.items.count }
        if let judge { return !judge.isComplete }
        return !isSolved
    }

    private var scoreAccuracy: Double {
        hunt?.scoreAccuracy ?? balance?.scoreAccuracy ?? privacy?.scoreAccuracy ?? judge?.scoreAccuracy ?? 0
    }

    /// 0 = level, 1 = fully tilted: the fairness gap, or how much is still undecided.
    private var fairnessTilt: Float {
        if let hunt { return hunt.isSolved ? 0 : 1 }
        if let balance { return Float(balance.fairnessGap) }
        if let privacy { return 1 - Float(privacy.decisions.count) / Float(max(privacy.items.count, 1)) }
        if let judge { return 1 - Float(judge.causeAnswers.count + judge.fixAnswers.count) / Float(max(judge.cases.count * 2, 1)) }
        return 0
    }

    // MARK: Stage

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.5, 0, 0.2]
        world.cat.stopWalking()
        let base = PropFactory.pedestal(color: Color(red: 0.55, green: 0.45, blue: 0.35), radius: 0.3)
        base.position = [-0.45, 0, 0.3]
        world.addProp(base, id: "scale_base")
        let post = ModelEntity(mesh: .generateBox(size: [0.05, 0.6, 0.05], cornerRadius: 0.01), materials: [Materials.matte(Color(red: 0.45, green: 0.35, blue: 0.25))])
        post.position = [-0.45, 0.4, 0.3]
        world.addProp(post, id: "scale_post")
        let beam = ModelEntity(mesh: .generateBox(size: [0.7, 0.03, 0.04], cornerRadius: 0.01), materials: [Materials.glossy(Color(red: 0.85, green: 0.7, blue: 0.3))])
        beam.position = [-0.45, 0.72, 0.3]
        for (index, side) in [-1, 1].enumerated() {
            let string = ModelEntity(mesh: .generateBox(size: [0.01, 0.18, 0.01]), materials: [Materials.matte(Color.gray)])
            string.position = [Float(side) * 0.33, -0.1, 0]
            beam.addChild(string)
            let pan = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: 0.12), materials: [Materials.glossy(Color(red: 0.85, green: 0.7, blue: 0.3))])
            pan.position = [Float(side) * 0.33, -0.2, 0]
            pan.name = "pan_\(index)"
            beam.addChild(pan)
        }
        world.addProp(beam, id: "scale_beam")
        world.cat.lookAt([-0.45, 0.72, 0.3])
        targetTilt = fairnessTilt
        tilt = targetTilt
        applyTilt()
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private func applyTilt() {
        guard let beam = world.prop(id: "scale_beam") else { return }
        beam.orientation = simd_quatf(angle: -0.35 * tilt, axis: [0, 0, 1])
    }

    private func frame(_ dt: Float) {
        if abs(tilt - targetTilt) > 0.001 {
            tilt += (targetTilt - tilt) * min(1, dt * 4)
            applyTilt()
        }
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
        if let hunt { session.progress = hunt.isSolved ? 1 : 0 }
        if let balance { session.progress = Double(balance.coatsAtTarget) / Double(CatCoat.allCases.count) }
        if let privacy { session.progress = Double(privacy.decisions.count) / Double(max(privacy.items.count, 1)) }
        if let judge { session.progress = Double(judge.causeAnswers.count + judge.fixAnswers.count) / Double(max(judge.cases.count * 2, 1)) }
        targetTilt = fairnessTilt
    }

    private func react() {
        updateProgress()
        if isSolved {
            world.cat.set(emotion: .proud)
        } else {
            world.cat.set(emotion: .curious)
        }
    }

    // MARK: Actions

    func pick(_ coat: CatCoat) {
        guard !isDone, var challenge = hunt, !challenge.isSolved else { return }
        let right = challenge.pick(coat)
        hunt = challenge
        if right {
            feedback = .rightPick(coat)
            react()
            confirm()
            return
        } else {
            feedback = .wrongPick
            world.cat.play(gesture: .shake)
            app.say(.wrong)
        }
        react()
    }

    func add(_ cardID: String) {
        guard !isDone, var challenge = balance else { return }
        if challenge.add(cardID) {
            balance = challenge
            if challenge.isSolved { app.say(.aiLearned) }
            react()
        }
    }

    func remove(_ cardID: String) {
        guard !isDone, var challenge = balance else { return }
        if challenge.remove(cardID) {
            balance = challenge
            react()
        }
    }

    func decide(_ itemID: String, keep: Bool) {
        guard !isDone, var challenge = privacy else { return }
        challenge.decide(itemID, keep: keep)
        privacy = challenge
        react()
    }

    func answerCause(_ caseID: String, _ cause: FairCause) {
        guard !isDone, var challenge = judge else { return }
        challenge.answerCause(caseID, cause)
        judge = challenge
        react()
    }

    func answerFix(_ caseID: String, _ fix: FairFix) {
        guard !isDone, var challenge = judge else { return }
        challenge.answerFix(caseID, fix)
        judge = challenge
        react()
    }

    /// A hint does one small step of the solution for the child.
    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        session.noteHint()
        app.say(.hint)
        if let hunt {
            hintCoat = hunt.missingCoat
        } else if var challenge = balance {
            if let coat = CatCoat.allCases.first(where: { challenge.count($0) < challenge.target }),
               let card = challenge.pool.first(where: { $0.coat == coat }) {
                challenge.add(card.id)
                balance = challenge
            }
        } else if var challenge = privacy {
            if let item = challenge.items.first(where: { challenge.decision(for: $0.id) == nil || challenge.isCorrect($0) == false }) {
                challenge.decide(item.id, keep: item.shouldKeep)
                privacy = challenge
            }
        } else if var challenge = judge {
            if let item = challenge.cases.first(where: { challenge.causeAnswers[$0.id] == nil }) {
                challenge.answerCause(item.id, item.cause)
            } else if let item = challenge.cases.first(where: { challenge.fixAnswers[$0.id] == nil }) {
                challenge.answerFix(item.id, item.fix)
            }
            judge = challenge
        }
        react()
    }

    /// The child is done: celebrate and score.
    func confirm() {
        guard canConfirm else { return }
        isDone = true
        session.progress = 1
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        app.say(.aiSorted)
        finishCountdown = 1.8
    }
}
