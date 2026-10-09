import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Reward Maze challenge: the child shapes the maze (treat, puddles), AI CAT explores with
/// tabular Q-learning, the tiles warm up with the learned values and the kitten tries its best path.
@MainActor
@Observable
final class RewardMazeController {
    enum Phase: Equatable {
        case editing, exploring, testing, done
    }

    enum Notice: Equatable {
        case tooClose, budget, unreachable, needTreat, wandered, puddle, straight
    }

    let spec: ChallengeSpec
    private(set) var challenge: MazeChallenge
    private(set) var phase: Phase = .editing
    private(set) var tool: MazeTile
    private(set) var catCell: MazeCell
    private(set) var heat: [Double]
    private(set) var notice: Notice?
    private(set) var hintsLeft: Int
    private(set) var epsilonIndex: Int

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var rng: SeededGenerator
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false

    // Replay of a path on stage (fast stepping, independent of the rig's walk).
    @ObservationIgnored private var replayCells: [MazeCell] = []
    @ObservationIgnored private var replayIndex = 0
    @ObservationIgnored private var replayProgress: Float = 0
    @ObservationIgnored private var replayStepDuration: Float = 0.16
    @ObservationIgnored private var replayFrom = SIMD3<Float>(repeating: 0)
    @ObservationIgnored private var onReplayEnd: (() -> Void)?

    static let maxAnimatedSteps = 40

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 104_729 &+ UInt64(spec.index) &* 13
        let made = MazeContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
        challenge = made
        rng = SeededGenerator(seed: seed &* 31 &+ 7)
        tool = made.treatBudget > 0 ? .treat : .puddle
        catCell = made.world.start
        heat = Array(repeating: 0, count: made.world.size * made.world.size)
        epsilonIndex = made.epsilonOptions.count > 1 ? 1 : 0
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived state for the board

    var size: Int { challenge.world.size }
    var isDone: Bool { phase == .done }
    var isBusy: Bool { phase == .exploring || phase == .testing }
    var canEdit: Bool { phase == .editing }
    var canExplore: Bool { phase == .editing && challenge.canExplore }
    var canRequestHint: Bool { hintsLeft > 0 && canExplore }
    var showsToolPicker: Bool { challenge.treatBudget > 0 && challenge.puddleBudget > 0 }
    var showsCuriosity: Bool { challenge.epsilonOptions.count > 1 }
    var lastBatch: MazeBatch? { challenge.lastBatch }
    var batches: Int { challenge.batches }

    func heat(at cell: MazeCell) -> Double { heat[cell.y * size + cell.x] }
    func tile(at cell: MazeCell) -> MazeTile { challenge.world[cell] }
    var startCell: MazeCell { challenge.world.start }

    // MARK: Stage

    var cellSize: Float { min(0.32, 2.0 / Float(size)) }

    func worldPosition(of cell: MazeCell) -> SIMD3<Float> {
        let half = Float(size - 1) * cellSize / 2
        return SIMD3<Float>(-half + Float(cell.x) * cellSize, 0, half - Float(cell.y) * cellSize)
    }

    static let baseTileColor = Color(red: 0.80, green: 0.86, blue: 0.72)
    static let wallColor = Color(red: 0.36, green: 0.52, blue: 0.30)

    /// Tile colour for a value v ∈ [−1, 1]: warm orange for expected treats, blue for expected trouble.
    static func heatColor(_ value: Double) -> Color {
        let v = max(-1, min(1, value))
        if v >= 0 {
            let t = v
            return Color(red: 0.80 + (1.0 - 0.80) * t, green: 0.86 + (0.62 - 0.86) * t, blue: 0.72 + (0.20 - 0.72) * t)
        } else {
            let t = -v
            return Color(red: 0.80 + (0.35 - 0.80) * t, green: 0.86 + (0.55 - 0.86) * t, blue: 0.72 + (0.95 - 0.72) * t)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        let maze = challenge.world
        for cell in maze.allCells {
            if maze[cell] == .wall {
                let wall = ModelEntity(mesh: .generateBox(size: [cellSize * 0.94, 0.14, cellSize * 0.94], cornerRadius: 0.015),
                                       materials: [Materials.matte(Self.wallColor)])
                wall.position = worldPosition(of: cell) + [0, 0.07, 0]
                wall.components.set(GroundingShadowComponent(castsShadow: true))
                world.addProp(wall, id: "wall_\(cell.x)_\(cell.y)")
            } else {
                let tile = ModelEntity(mesh: .generateBox(size: [cellSize * 0.92, 0.02, cellSize * 0.92], cornerRadius: 0.01),
                                       materials: [Materials.matte(Self.baseTileColor)])
                tile.position = worldPosition(of: cell) + [0, 0.01, 0]
                world.addProp(tile, id: Self.tileID(cell))
            }
        }
        syncMarkers()
        placeCat(at: maze.start)
        world.cat.lookAt(nil)
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private static func tileID(_ cell: MazeCell) -> String { "tile_\(cell.x)_\(cell.y)" }

    /// Adds or removes the treat and puddle entities so the stage matches the map.
    private func syncMarkers() {
        let maze = challenge.world
        for cell in maze.allCells {
            let puddleID = "puddle_\(cell.x)_\(cell.y)"
            let treatID = "treat_\(cell.x)_\(cell.y)"
            switch maze[cell] {
            case .puddle:
                if world.prop(id: puddleID) == nil {
                    let puddle = ModelEntity(mesh: .generateCylinder(height: 0.015, radius: cellSize * 0.36),
                                             materials: [Materials.glossy(Color(red: 0.3, green: 0.6, blue: 0.95))])
                    puddle.position = worldPosition(of: cell) + [0, 0.03, 0]
                    world.addProp(puddle, id: puddleID)
                }
                world.removeProp(id: treatID)
            case .treat:
                if world.prop(id: treatID) == nil {
                    let fish = ModelEntity(mesh: MeshResource(shape: .generateCapsule(height: 0.16, radius: 0.045)),
                                           materials: [Materials.glossy(Color.orange)])
                    fish.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                    fish.position = worldPosition(of: cell) + [0, 0.06, 0]
                    fish.components.set(GroundingShadowComponent(castsShadow: true))
                    world.addProp(fish, id: treatID)
                }
                world.removeProp(id: puddleID)
            default:
                world.removeProp(id: puddleID)
                world.removeProp(id: treatID)
            }
        }
    }

    private func placeCat(at cell: MazeCell) {
        world.cat.stopWalking()
        catCell = cell
        world.cat.root.position = worldPosition(of: cell)
        world.cat.root.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    }

    /// Repaints every tile from the learner's values.
    private func refreshHeat() {
        let q = challenge.learner.q
        let maze = challenge.world
        var values = Array(repeating: 0.0, count: size * size)
        for cell in maze.allCells where maze[cell] != .wall {
            let v = q.value(at: cell)
            values[cell.y * size + cell.x] = v
            if let tile = world.prop(id: Self.tileID(cell)) as? ModelEntity {
                tile.model?.materials = [Materials.matte(Self.heatColor(v))]
            }
        }
        heat = values
    }

    private func frame(_ dt: Float) {
        advanceReplay(dt)
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: challenge.scoreAccuracy, app: app)
        } else {
            finishCountdown = next
        }
    }

    // MARK: Replay engine

    private func replay(_ cells: [MazeCell], stepDuration: Float, completion: @escaping () -> Void) {
        var cleaned: [MazeCell] = []
        for cell in cells where cleaned.last != cell { cleaned.append(cell) }   // bumps do not move the cat
        guard cleaned.count > 1 else {
            completion()
            return
        }
        placeCat(at: cleaned[0])
        replayCells = cleaned
        replayIndex = 1
        replayProgress = 0
        replayStepDuration = max(0.05, stepDuration)
        replayFrom = worldPosition(of: cleaned[0])
        onReplayEnd = completion
    }

    private func advanceReplay(_ dt: Float) {
        guard replayIndex < replayCells.count else { return }
        let target = worldPosition(of: replayCells[replayIndex])
        replayProgress += dt / replayStepDuration
        let t = min(replayProgress, 1)
        let hop = sin(t * .pi) * 0.035
        world.cat.root.position = replayFrom + (target - replayFrom) * t + [0, hop, 0]
        let delta = target - replayFrom
        if abs(delta.x) > 1e-5 || abs(delta.z) > 1e-5 {
            world.cat.root.orientation = simd_quatf(angle: atan2(delta.x, delta.z), axis: [0, 1, 0])
        }
        if replayProgress >= 1 {
            catCell = replayCells[replayIndex]
            replayFrom = target
            replayIndex += 1
            replayProgress = 0
            if replayIndex >= replayCells.count {
                world.cat.root.position = target
                let done = onReplayEnd
                onReplayEnd = nil
                done?()
            }
        }
    }

    // MARK: Editing

    func select(tool newTool: MazeTile) {
        guard canEdit, newTool == .treat || newTool == .puddle else { return }
        tool = newTool
    }

    func tap(_ cell: MazeCell) {
        guard canEdit else { return }
        let result = challenge.tap(cell, tool: tool)
        switch result {
        case .placed, .removed:
            notice = nil
            syncMarkers()
            refreshHeat()
            placeCat(at: challenge.world.start)
            if result == .placed, tool == .treat { app.say(.correct) }
            if !challenge.hasTreat {
                notice = .needTreat
            } else if !challenge.world.isTreatReachable {
                notice = .unreachable
            }
        case .tooClose:
            notice = .tooClose
            app.say(.encouragement)
        case .budgetExhausted:
            notice = .budget
        case .blocked:
            break
        }
        updateProgress()
    }

    func selectCuriosity(_ index: Int) {
        guard canEdit, challenge.epsilonOptions.indices.contains(index) else { return }
        epsilonIndex = index
        challenge.setEpsilon(challenge.epsilonOptions[index])
    }

    // MARK: Exploring

    func explore() {
        guard canExplore, let batch = challenge.explore(using: &rng) else {
            if !challenge.hasTreat { notice = .needTreat } else if !challenge.world.isTreatReachable { notice = .unreachable }
            return
        }
        app.say(.challengeStart)
        play(batch, animateExploration: true)
    }

    func requestHint() {
        guard canRequestHint, let batch = challenge.hint(using: &rng) else { return }
        hintsLeft -= 1
        session.noteHint()
        app.say(.hint)
        play(batch, animateExploration: false)
    }

    private func play(_ batch: MazeBatch, animateExploration: Bool) {
        notice = nil
        phase = .exploring
        world.cat.set(emotion: .curious)
        let firstPath = animateExploration ? Array((batch.episodes.first?.path ?? []).prefix(Self.maxAnimatedSteps + 1)) : []
        replay(firstPath, stepDuration: 0.14) { [weak self] in
            guard let self else { return }
            self.refreshHeat()
            self.phase = .testing
            self.world.cat.set(emotion: .thinking)
            self.replay(batch.greedy.path, stepDuration: 0.3) { [weak self] in
                self?.finishBatch(batch)
            }
        }
    }

    private func finishBatch(_ batch: MazeBatch) {
        updateProgress()
        if batch.solved {
            phase = .done
            session.progress = 1
            world.cat.set(emotion: .excited)
            world.cat.play(gesture: .jump)
            world.celebrate()
            app.say(.aiLearned)
            finishCountdown = 1.8
            return
        }
        switch batch.greedy.outcome {
        case .puddle:
            notice = .puddle
            world.cat.set(emotion: .sad)
            world.cat.play(gesture: .shake)
            app.say(.wrong)
        case .wandered:
            notice = .wandered
            world.cat.set(emotion: .thinking)
            app.say(.aiNeedsMore)
        case .treat:
            notice = .straight   // reached the treat but the master rule wants a real detour
            world.cat.set(emotion: .curious)
            app.say(.encouragement)
        }
        phase = .editing
        placeCat(at: challenge.world.start)
    }

    /// Progress: how close the best known path gets to the treat (0 before exploring, 1 when solved).
    private func updateProgress() {
        guard !challenge.isSolved else {
            session.progress = 1
            return
        }
        guard let batch = challenge.lastBatch, let treat = challenge.world.treat, let last = batch.greedy.path.last else {
            session.progress = 0
            return
        }
        let total = Double(max(challenge.world.start.manhattan(to: treat), 1))
        let remaining = Double(last.manhattan(to: treat))
        session.progress = max(0, min(0.9, 1 - remaining / total))
    }
}
