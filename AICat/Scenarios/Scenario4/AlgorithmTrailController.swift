import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Algorithm Trail challenge: the child assembles instruction blocks, AI CAT executes them
/// exactly, walking the grid on stage. Reaching the fish solves the challenge.
@MainActor
@Observable
final class AlgorithmTrailController {
    let spec: ChallengeSpec
    private(set) var challenge: TrailChallenge
    private(set) var catCell: TrailCell
    private(set) var catDirection: TrailDirection
    private(set) var isRunning = false
    private(set) var isDone = false
    private(set) var lastOutcome: TrailOutcome?
    private(set) var hintsLeft: Int
    private(set) var hintedBlock: TrailBlock?
    var repeatCount = 3

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var runTask: Task<Void, Never>?

    static let cellSize: Float = 0.32

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 2_147_483_647 &+ UInt64(spec.index)
        let made = TrailContent.make(spec: spec, difficulty: app.profile.difficulty, seed: seed)
        challenge = made
        catCell = made.world.start
        catDirection = made.world.startDirection
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Stage

    private var originX: Float { -Float(challenge.world.width - 1) * Self.cellSize / 2 }
    private var originZ: Float { 0.55 }

    func worldPosition(of cell: TrailCell) -> SIMD3<Float> {
        SIMD3<Float>(originX + Float(cell.x) * Self.cellSize, 0, originZ - Float(cell.y) * Self.cellSize)
    }

    private func yaw(for direction: TrailDirection) -> Float {
        switch direction {
        case .east: return .pi / 2
        case .north: return .pi
        case .west: return -.pi / 2
        case .south: return 0
        }
    }

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        let w = challenge.world
        for y in 0..<w.height {
            for x in 0..<w.width {
                let cell = TrailCell(x, y)
                let tile = ModelEntity(mesh: .generateBox(size: [Self.cellSize * 0.92, 0.02, Self.cellSize * 0.92], cornerRadius: 0.01),
                                       materials: [Materials.stone(cell == w.goal ? Color.yellow : Color(red: 0.78, green: 0.86, blue: 0.70), repeats: 1)])
                tile.position = worldPosition(of: cell) + [0, 0.01, 0]
                world.addProp(tile, id: "tile_\(x)_\(y)")
                if w.isPuddle(cell) {
                    let puddle = ModelEntity(mesh: .generateCylinder(height: 0.015, radius: Self.cellSize * 0.36), materials: [Materials.glossy(Color(red: 0.3, green: 0.6, blue: 0.95))])
                    puddle.position = worldPosition(of: cell) + [0, 0.03, 0]
                    world.addProp(puddle, id: "puddle_\(x)_\(y)")
                }
            }
        }
        let fish = ModelEntity(mesh: Meshes.capsule(height: 0.16, radius: 0.045), materials: [Materials.glossy(Color.orange)])
        fish.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        fish.position = worldPosition(of: w.goal) + [0, 0.06, 0]
        fish.components.set(GroundingShadowComponent(castsShadow: true))
        world.addProp(fish, id: "fish")
        resetCat()
        world.onFrame = { [weak self] dt in self?.frame(dt) }
    }

    private func resetCat() {
        world.cat.stopWalking()
        catCell = challenge.world.start
        catDirection = challenge.world.startDirection
        world.cat.root.position = worldPosition(of: catCell)
        world.cat.root.orientation = simd_quatf(angle: yaw(for: catDirection), axis: [0, 1, 0])
        world.cat.lookAt(nil)
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

    // MARK: Program editing

    var program: [TrailBlock] { challenge.program }
    var palette: [TrailBlockKind] { challenge.palette }
    var budgetText: String { "\(challenge.cost)/\(challenge.maxCost)" }

    func append(_ kind: TrailBlockKind) {
        guard !isRunning, !isDone else { return }
        let block: TrailBlock
        switch kind {
        case .forward: block = .forward
        case .turnLeft: block = .turnLeft
        case .turnRight: block = .turnRight
        case .jump: block = .jump
        case .ifPuddleAhead: block = .ifPuddleAhead
        case .repeatTimes: block = .repeatForward(max(2, min(repeatCount, 5)))
        }
        if !challenge.append(block) {
            app.say(.encouragement)
        }
        hintedBlock = nil
    }

    func removeLast() {
        guard !isRunning, !isDone else { return }
        challenge.removeLast()
    }

    func clear() {
        guard !isRunning, !isDone else { return }
        challenge.clear()
    }

    var canRequestHint: Bool { hintsLeft > 0 && !isRunning && !isDone }

    func requestHint() {
        guard canRequestHint else { return }
        // A program that already reaches the fish does not need a hint: just run it (no hint spent).
        if TrailInterpreter.run(challenge.program, in: challenge.world).outcome == .goal {
            hintedBlock = nil
            app.say(.encouragement)
            return
        }
        hintsLeft -= 1
        session.noteHint()
        if let block = challenge.hint() {
            hintedBlock = block
            app.say(.hint)
        } else {
            challenge.clear()
            hintedBlock = challenge.hint()
            app.say(.aiNeedsMore)
        }
        if case .repeatForward(let count)? = hintedBlock {
            repeatCount = count
        }
    }

    /// Stops a run in progress (the view is going away).
    func stop() {
        runTask?.cancel()
        runTask = nil
        world.cat.stopWalking()
        isRunning = false
    }

    // MARK: Running

    func run() {
        guard !isRunning, !isDone, !challenge.program.isEmpty else { return }
        isRunning = true
        hintedBlock = nil
        resetCat()
        let result = challenge.run()
        lastOutcome = nil
        app.say(.challengeStart)
        runTask?.cancel()
        runTask = Task { [weak self] in
            guard let self else { return }
            for event in result.events {
                guard !Task.isCancelled else { return }
                await self.animate(event)
            }
            guard !Task.isCancelled else { return }
            self.lastOutcome = result.outcome
            switch result.outcome {
            case .goal:
                self.isRunning = false
                self.isDone = true
                self.session.progress = 1
                self.world.celebrate()
                self.world.cat.play(gesture: .jump)
                self.finishCountdown = 1.4
            case .splash:
                self.app.say(.wrong)
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                self.resetCat()
                self.isRunning = false
            case .lost, .tooLong:
                self.app.say(.encouragement)
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                self.resetCat()
                self.isRunning = false
            }
        }
    }

    /// Resumes a continuation exactly once, whichever of two callers gets there first.
    private final class ResumeOnce {
        private var done = false
        private let continuation: CheckedContinuation<Void, Never>
        init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
        func resume() {
            guard !done else { return }
            done = true
            continuation.resume()
        }
    }

    /// Walks the cat to `cell` and waits for the arrival. A safety timer guarantees the program keeps
    /// running even if the stage stops updating (view dismissed mid-run, rig replaced).
    private func walk(to cell: TrailCell) async {
        let target = worldPosition(of: cell)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce(continuation)
            world.cat.walk(to: target) { once.resume() }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.walkTimeout * 1_000_000_000))
                once.resume()
            }
        }
        world.cat.root.position = target
        catCell = cell
    }

    /// Upper bound for one walk (one or two cells at kitten speed) before the safety timer fires.
    private static let walkTimeout: Double = 4.0

    private func animate(_ event: TrailEvent) async {
        switch event {
        case .moved(let to):
            await walk(to: to)
        case .turned(let direction):
            catDirection = direction
            world.cat.root.orientation = simd_quatf(angle: yaw(for: direction), axis: [0, 1, 0])
            try? await Task.sleep(nanoseconds: 350_000_000)
        case .jumped(_, let to):
            world.cat.play(gesture: .jump)
            await walk(to: to)
        case .bumped:
            world.cat.play(gesture: .shake)
            try? await Task.sleep(nanoseconds: 400_000_000)
        case .splashed(let at):
            await walk(to: at)
            world.cat.set(emotion: .sad)
            world.cat.play(gesture: .shake)
            try? await Task.sleep(nanoseconds: 500_000_000)
        case .reachedGoal:
            world.cat.set(emotion: .excited)
        case .stepLimit:
            world.cat.set(emotion: .sleepy)
        }
    }
}
