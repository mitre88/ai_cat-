import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Pattern Garden challenge: fruits in the 3-D world, drag & drop, AI CAT learning the rule
/// from the child's examples and carrying the remaining fruits itself.
@MainActor
@Observable
final class PatternGardenController: WorldInteraction {
    enum Status: Equatable {
        case watching, thinking, learned, sorting, done
    }

    private enum AIState {
        case idle
        case walkingToFruit(AIMove)
        case carrying(AIMove)
        case finished
    }

    static let basketColors: [Color] = [Color(red: 0.62, green: 0.42, blue: 0.22), Color(red: 0.25, green: 0.50, blue: 0.85)]
    static let basketRadius: Float = 0.24
    static let basketHeight: Float = 0.18
    static let dropRadius: Float = 0.36
    static let liftHeight: Float = 0.13

    let spec: ChallengeSpec
    private(set) var challenge: SortingChallenge
    private(set) var status: Status = .watching
    private(set) var hintsLeft: Int
    private(set) var learnedStatements: [String] = []
    private(set) var hintFruitID: String?
    private(set) var hintBasketID: String?

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var fruitEntities: [String: ModelEntity] = [:]
    @ObservationIgnored private var homePositions: [String: SIMD3<Float>] = [:]
    @ObservationIgnored private var basketCenters: [String: SIMD3<Float>] = [:]
    @ObservationIgnored private var draggingID: String?
    @ObservationIgnored private var aiQueue: [AIMove] = []
    @ObservationIgnored private var aiState: AIState = .idle
    @ObservationIgnored private var carriedFruitID: String?
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var mistakesSinceHint = 0
    @ObservationIgnored private var saidNeedsMore = false
    @ObservationIgnored private var started = false

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 7919 &+ UInt64(spec.index) &* 131
        challenge = SortingContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
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
        buildScene()
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        if challenge.ruleIsStated {
            let sentence = ruleStatements.joined(separator: " ")
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard let self, self.status == .watching else { return }
                self.app.say(text: sentence, emotion: .curious, gesture: .headTilt)
            }
        }
    }

    private func buildScene() {
        world.clearProps()
        for (i, basket) in challenge.baskets.enumerated() {
            let x: Float = i == 0 ? -0.95 : 0.95
            let center = SIMD3<Float>(x, 0, 0.25)
            let entity = FruitFactory.basket(index: basket.index, color: Self.basketColors[i % Self.basketColors.count], radius: Self.basketRadius, height: Self.basketHeight)
            entity.position = center
            world.addProp(entity, id: basket.id)
            basketCenters[basket.id] = center
        }
        let count = challenge.fruits.count
        let columns = min(count, 5)
        for (i, fruit) in challenge.fruits.enumerated() {
            let row = i / columns
            let column = i % columns
            let x: Float = columns == 1 ? 0 : -0.72 + 1.44 * Float(column) / Float(columns - 1)
            let z: Float = 0.78 + Float(row) * 0.30
            let entity = FruitFactory.fruit(fruit)
            entity.position = [x, 0.35 + Float(i) * 0.02, z]
            world.addProp(entity, id: fruit.id)
            fruitEntities[fruit.id] = entity
            homePositions[fruit.id] = [x, 0, z]
        }
        world.cat.root.position = [0, 0, 0.1]
        world.cat.stopWalking()
        world.cat.lookAt(nil)
    }

    // MARK: Rule text

    var ruleStatements: [String] {
        challenge.rule.statements.map(sentence(for:))
    }

    private func basketIndex(_ id: String) -> Int {
        challenge.basket(id: id)?.index ?? 0
    }

    private func sentence(for statement: SortingRule.Statement) -> String {
        switch statement {
        case .valueToBasket(let valueKey, let basketID):
            return L10n.format("rule.value_to_basket", L10n.string(valueKey.raw), basketIndex(basketID))
        case .conjunction(let firstKey, let secondKey, let yes, let no):
            return L10n.format("rule.conjunction", L10n.string(firstKey.raw), L10n.string(secondKey.raw), basketIndex(yes), basketIndex(no))
        }
    }

    private func statements(for rule: LearnedRule) -> [SortingRule.Statement] {
        switch rule {
        case .stump(let stump):
            guard let attribute = FruitAttribute(rawValue: stump.attribute) else { return [] }
            return stump.mapping.keys.sorted().map { value in
                .valueToBasket(valueKey: fruitValueKey(attribute: attribute, value: value), basketID: stump.mapping[value] ?? "")
            }
        case .conjunction(let rule):
            guard let a = FruitAttribute(rawValue: rule.attribute1), let b = FruitAttribute(rawValue: rule.attribute2) else { return [] }
            return [.conjunction(firstKey: fruitValueKey(attribute: a, value: rule.value1), secondKey: fruitValueKey(attribute: b, value: rule.value2), yesBasketID: rule.positiveLabel, noBasketID: rule.negativeLabel)]
        }
    }

    // MARK: Dragging

    func dragChanged(_ value: EntityTargetValue<DragGesture.Value>) {
        guard status != .done, status != .sorting else { return }
        if draggingID == nil {
            guard let id = DragMath.propID(for: value.entity, among: Set(fruitEntities.keys)),
                  challenge.placements[id] == nil,
                  let entity = fruitEntities[id] else { return }
            entity.physicsBody?.mode = .kinematic
            draggingID = id
            world.cat.set(emotion: .curious)
        }
        guard let id = draggingID, let entity = fruitEntities[id],
              let point = DragMath.groundPoint(for: value, height: Self.liftHeight) else { return }
        let clamped = DragPlaneMath.clamped(point, minX: -1.7, maxX: 1.7, minZ: -0.6, maxZ: 1.7)
        entity.position = [clamped.x, Self.liftHeight, clamped.z]
        world.cat.lookAt(entity.position)
    }

    func dragEnded(_ value: EntityTargetValue<DragGesture.Value>) {
        guard let id = draggingID, let entity = fruitEntities[id] else {
            draggingID = nil
            return
        }
        draggingID = nil
        let targets = challenge.baskets.map {
            DragPlaneMath.Target(id: $0.id, center: basketCenters[$0.id] ?? .zero, radius: Self.dropRadius)
        }
        if let target = DragPlaneMath.target(containing: entity.position, among: targets) {
            handlePlacement(fruitID: id, basketID: target.id, entity: entity)
        } else {
            entity.physicsBody?.mode = .dynamic
            world.cat.lookAt(nil)
        }
    }

    private func handlePlacement(fruitID: String, basketID: String, entity: ModelEntity) {
        let outcome = challenge.place(fruitID: fruitID, in: basketID)
        switch outcome {
        case .correct:
            settle(entity, into: basketID)
            session.progress = Double(challenge.placements.count) / Double(challenge.fruits.count)
            mistakesSinceHint = 0
            world.cat.play(gesture: .nod)
            app.say(.correct)
            tryLearn()
            checkCompletion()
        case .wrong:
            mistakesSinceHint += 1
            bounceHome(entity, id: fruitID)
            world.cat.play(gesture: .shake)
            app.say(.wrong)
            if app.profile.ageBand.autoHints || mistakesSinceHint >= 2 {
                giveHint(automatic: true, preferring: fruitID)
            }
        case .ignored:
            entity.physicsBody?.mode = .dynamic
        }
    }

    private func settle(_ entity: ModelEntity, into basketID: String) {
        let center = basketCenters[basketID] ?? .zero
        entity.position = [center.x + Float.random(in: -0.04...0.04), Self.basketHeight + 0.12, center.z + Float.random(in: -0.04...0.04)]
        entity.physicsBody?.mode = .dynamic
        var input = InputTargetComponent()
        input.isEnabled = false
        entity.components.set(input)
    }

    private func bounceHome(_ entity: ModelEntity, id: String) {
        let home = homePositions[id] ?? .zero
        entity.physicsBody?.mode = .kinematic
        let transform = Transform(scale: entity.scale, rotation: entity.orientation, translation: [home.x, 0.18, home.z])
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.45, timingFunction: .easeInOut)
        Task { [weak entity] in
            try? await Task.sleep(nanoseconds: 480_000_000)
            entity?.physicsBody?.mode = .dynamic
        }
    }

    // MARK: AI CAT learns

    private func tryLearn() {
        guard status == .watching || status == .thinking else { return }
        if let rule = challenge.letAICatLearn() {
            status = .learned
            learnedStatements = statements(for: rule).map(sentence(for:))
            world.cat.play(gesture: .jump)
            app.say(.aiLearned)
            let moves = challenge.aiCatSortsRemaining()
            session.progress = Double(challenge.placements.count) / Double(challenge.fruits.count)
            if moves.isEmpty {
                checkCompletion()
            } else {
                aiQueue = moves
                aiState = .idle
                status = .sorting
            }
        } else if challenge.examplesForLearning.count >= challenge.minExamplesToLearn, !saidNeedsMore {
            saidNeedsMore = true
            status = .thinking
            app.say(.aiNeedsMore)
        }
    }

    private func frame(_ dt: Float) {
        if let countdown = finishCountdown {
            let next = countdown - dt
            if next <= 0 {
                finishCountdown = nil
                session.finish(accuracy: challenge.accuracy, app: app)
            } else {
                finishCountdown = next
            }
        }
        if let id = carriedFruitID, let entity = fruitEntities[id] {
            let head = world.cat.headPosition
            let forward = world.cat.root.orientation.act(SIMD3<Float>(0, 0, 1))
            let r = Float(world.cat.morphology.headRadius)
            entity.position = head + forward * (r * 1.25) + SIMD3<Float>(0, -r * 0.35, 0)
        }
        guard status == .sorting else { return }
        if case .idle = aiState {
            guard let move = aiQueue.first else {
                aiState = .finished
                finishAISorting()
                return
            }
            aiQueue.removeFirst()
            guard let entity = fruitEntities[move.fruit.id] else { return }
            entity.physicsBody?.mode = .kinematic
            aiState = .walkingToFruit(move)
            let standPoint = SIMD3<Float>(entity.position.x, 0, entity.position.z - 0.16)
            world.cat.animator.onArrive = { [weak self] in self?.pickUp(move) }
            world.cat.walk(to: standPoint)
        }
    }

    private func pickUp(_ move: AIMove) {
        carriedFruitID = move.fruit.id
        aiState = .carrying(move)
        let center = basketCenters[move.basketID] ?? .zero
        let standPoint = SIMD3<Float>(center.x * 0.72, 0, center.z + 0.34)
        world.cat.animator.onArrive = { [weak self] in self?.drop(move) }
        world.cat.walk(to: standPoint)
    }

    private func drop(_ move: AIMove) {
        carriedFruitID = nil
        if let entity = fruitEntities[move.fruit.id] {
            settle(entity, into: move.basketID)
        }
        world.cat.play(gesture: .nod)
        aiState = .idle
    }

    private func finishAISorting() {
        world.cat.lookAt(nil)
        if challenge.isComplete {
            app.say(.aiSorted)
            checkCompletion()
        } else {
            status = .thinking
            saidNeedsMore = false
            app.say(.aiNeedsMore)
        }
    }

    private func checkCompletion() {
        guard challenge.isComplete, status != .done else { return }
        status = .done
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        finishCountdown = 1.3
    }

    // MARK: Hints

    var canRequestHint: Bool {
        hintsLeft > 0 && (status == .watching || status == .thinking)
    }

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        giveHint(automatic: false, preferring: nil)
    }

    private func giveHint(automatic: Bool, preferring fruitID: String?) {
        guard hintFruitID == nil else { return }
        let fruit: Fruit
        if let id = fruitID, let preferred = challenge.fruit(id: id), challenge.placements[id] == nil {
            fruit = preferred
            _ = challenge.useHint()
        } else if let hint = challenge.useHint() {
            fruit = hint.fruit
        } else {
            return
        }
        session.noteHint()
        let basketID = challenge.expectedBasket(for: fruit)
        hintFruitID = fruit.id
        hintBasketID = basketID
        guard let entity = fruitEntities[fruit.id] else { return }
        let original = entity.model?.materials ?? []
        entity.model?.materials = [Materials.glowing(FruitFactory.color(for: fruit.color))]
        world.cat.lookAt(entity.position)
        app.say(.hint)
        Task { [weak self, weak entity] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            entity?.model?.materials = original
            self?.hintFruitID = nil
            self?.hintBasketID = nil
        }
    }

    var sortedCount: Int { challenge.placements.count }
    var totalCount: Int { challenge.fruits.count }
}
