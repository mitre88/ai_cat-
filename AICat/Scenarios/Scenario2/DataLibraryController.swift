import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Data Library challenge: the child labels animal cards on the board, every label becomes a
/// data block in AI CAT's knowledge pile on stage, and a k-NN classifier (the cat's whole brain here)
/// is scored live on hidden test cards.
@MainActor
@Observable
final class DataLibraryController {
    let spec: ChallengeSpec
    private(set) var challenge: LabelingChallenge
    private(set) var selectedCardID: String?
    private(set) var hintsLeft: Int
    private(set) var hintCardID: String?
    private(set) var lastOutcome: LabelOutcome?
    private(set) var isDone = false

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var mistakesSinceHint = 0
    @ObservationIgnored private var started = false

    static let pileOrigin = SIMD3<Float>(-0.55, 0, 0.75)
    static let cubeSize: Float = 0.11

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 104_729 &+ UInt64(spec.index) &* 17
        challenge = LabelingContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 1 : 3
        case .master: hintsLeft = spec.isMaster ? 0 : 1
        }
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.35, 0, 0.1]
        world.cat.stopWalking()
        world.cat.lookAt(nil)
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        for card in challenge.cards where challenge.label(of: card.id) != nil {
            placeBlock(for: card)
        }
        selectedCardID = challenge.unlabeled.first?.id ?? challenge.wronglyLabeled.first?.id
        updateProgress()
        if !challenge.trapIDs.isEmpty {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard let self, !self.isDone else { return }
                self.app.say(.trapFound)
            }
        }
    }

    private func frame(_ dt: Float) {
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: challenge.childAccuracy, app: app)
        } else {
            finishCountdown = next
        }
    }

    // MARK: Board actions

    var cards: [AnimalCard] { challenge.cards }
    var speciesOptions: [Species] { challenge.species }
    var selectedCard: AnimalCard? { selectedCardID.flatMap { challenge.card(id: $0) } }
    var labeledCount: Int { challenge.cards.filter { challenge.isCorrectlyLabeled($0) }.count }
    var totalCount: Int { challenge.cards.count }
    var aiAccuracy: Double { challenge.aiAccuracy }

    func label(of card: AnimalCard) -> Species? { challenge.label(of: card.id) }
    func isWrong(_ card: AnimalCard) -> Bool { challenge.label(of: card.id) != nil && !challenge.isCorrectlyLabeled(card) }
    func isTrap(_ card: AnimalCard) -> Bool { challenge.isTrap(card.id) }

    func select(_ card: AnimalCard) {
        guard !isDone else { return }
        selectedCardID = card.id
        if let block = world.prop(id: blockID(for: card.id)) {
            world.cat.lookAt(block.position + [0, 0.1, 0])
        } else {
            world.cat.lookAt(nil)
        }
    }

    /// What AI CAT would answer for the selected card, from the child's labels only.
    var guess: (species: Species, votes: Int, neighbours: Int)? {
        guard let card = selectedCard, let prediction = challenge.aiGuess(for: card),
              let species = Species(rawValue: prediction.label) else { return nil }
        let total = prediction.votes.values.reduce(0, +)
        return (species, prediction.votes[prediction.label] ?? 0, total)
    }

    func label(_ species: Species) {
        guard !isDone, let card = selectedCard else { return }
        let outcome = challenge.label(cardID: card.id, as: species)
        lastOutcome = outcome
        switch outcome {
        case .correct:
            mistakesSinceHint = 0
            placeBlock(for: card)
            world.cat.play(gesture: .nod)
            app.say(.correct)
            advanceSelection()
        case .wrong:
            mistakesSinceHint += 1
            placeBlock(for: card)
            world.cat.play(gesture: .shake)
            app.say(.wrong)
            if app.profile.ageBand.autoHints || mistakesSinceHint >= 2 {
                giveHint(automatic: true, card: card)
            }
        case .ignored:
            break
        }
        updateProgress()
        reactToAccuracy()
        checkCompletion()
    }

    private func advanceSelection() {
        if let next = challenge.unlabeled.first {
            selectedCardID = next.id
        } else if let wrong = challenge.wronglyLabeled.first {
            selectedCardID = wrong.id
        } else {
            selectedCardID = nil
        }
    }

    private func updateProgress() {
        session.progress = Double(labeledCount) / Double(max(totalCount, 1))
    }

    private func reactToAccuracy() {
        guard challenge.labeledCount >= 3 else { return }
        let accuracy = challenge.aiAccuracy
        if accuracy >= 0.8 {
            world.cat.set(emotion: .proud)
        } else if accuracy < 0.5 {
            world.cat.set(emotion: .thinking)
        } else {
            world.cat.set(emotion: .curious)
        }
    }

    private func checkCompletion() {
        guard challenge.isComplete, !isDone else { return }
        isDone = true
        selectedCardID = nil
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        finishCountdown = 1.2
    }

    // MARK: Hints

    var canRequestHint: Bool { hintsLeft > 0 && !isDone }

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        giveHint(automatic: false, card: nil)
    }

    private func giveHint(automatic: Bool, card preferred: AnimalCard?) {
        guard hintCardID == nil else { return }
        let target: AnimalCard
        if let preferred, !challenge.isCorrectlyLabeled(preferred) {
            target = preferred
            _ = challenge.useHint()
        } else if let hint = challenge.useHint() {
            target = hint.card
        } else {
            return
        }
        session.noteHint()
        hintCardID = target.id
        selectedCardID = target.id
        app.say(.hint)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            self?.hintCardID = nil
        }
    }

    /// The species a hint points at (shown on the board while the hint is active).
    var hintSpecies: Species? {
        hintCardID.flatMap { challenge.card(id: $0)?.species }
    }

    // MARK: Stage: AI CAT's knowledge pile

    private func blockID(for cardID: String) -> String { "block_\(cardID)" }

    static func color(for species: Species) -> Color {
        switch species {
        case .cat: return Color(red: 0.55, green: 0.36, blue: 0.75)
        case .dog: return Color(red: 0.25, green: 0.55, blue: 0.9)
        case .bird: return Color(red: 0.98, green: 0.78, blue: 0.25)
        }
    }

    private func placeBlock(for card: AnimalCard) {
        guard let label = challenge.label(of: card.id),
              let index = challenge.cards.firstIndex(where: { $0.id == card.id }) else { return }
        let id = blockID(for: card.id)
        let wrong = label != card.species
        let material = wrong
            ? Materials.glowing(Color(red: 0.95, green: 0.3, blue: 0.3), intensity: 0.8)
            : Materials.glossy(Self.color(for: label))
        let columns = 4
        let column = index % columns
        let row = index / columns
        let size = Self.cubeSize
        let target = Self.pileOrigin + SIMD3<Float>(Float(column) * size * 1.3, size / 2, Float(row) * size * 1.3)
        if let existing = world.prop(id: id) as? ModelEntity {
            existing.model?.materials = [material]
            existing.position = target
            return
        }
        let block = ModelEntity(mesh: .generateBox(size: size, cornerRadius: size * 0.12), materials: [material])
        block.components.set(GroundingShadowComponent(castsShadow: true))
        block.position = target + [0, 0.5, 0]
        world.addProp(block, id: id)
        block.move(to: Transform(scale: .one, rotation: block.orientation, translation: target), relativeTo: block.parent, duration: 0.5, timingFunction: .easeOut)
        world.cat.lookAt(target)
    }
}
