import XCTest
@testable import AICatCore

final class MazeMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.rewardMaze).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testParseAndStep() {
        let world = MazeWorld.parse(["..T", ".#.", "S.."])
        XCTAssertEqual(world.size, 3)
        XCTAssertEqual(world.start, MazeCell(0, 0))
        XCTAssertEqual(world.treat, MazeCell(2, 2))
        XCTAssertEqual(world[MazeCell(1, 1)], .wall)
        XCTAssertEqual(world.step(from: MazeCell(0, 0), .south).bumped, true, "the border bumps")
        XCTAssertEqual(world.step(from: MazeCell(0, 1), .east).bumped, true, "walls bump")
        XCTAssertEqual(world.step(from: MazeCell(0, 0), .east).cell, MazeCell(1, 0))
        XCTAssertTrue(world.isTreatReachable)
        var blocked = world
        blocked[MazeCell(1, 2)] = .puddle
        blocked[MazeCell(2, 1)] = .puddle
        XCTAssertFalse(blocked.isTreatReachable, "puddles block the safe path")
    }

    func testQUpdateMath() {
        // The treat is north of the start; with ε = 0 and all values 0 the first action is north (tie-break).
        let world = MazeWorld.parse(["T.", "S."])
        var learner = MazeLearner(size: 2, epsilon: 0)
        var rng = SeededGenerator(seed: 1)
        let episode = learner.runEpisode(in: world, using: &rng)
        XCTAssertEqual(episode.outcome, .treat)
        XCTAssertEqual(episode.steps.count, 1)
        XCTAssertEqual(learner.q[MazeCell(0, 0), .north], 0.5, accuracy: 1e-12, "Q ← 0 + 0.5 · (1 − 0)")
        _ = learner.runEpisode(in: world, using: &rng)
        XCTAssertEqual(learner.q[MazeCell(0, 0), .north], 0.75, accuracy: 1e-12)
        // A bump: reward −0.1, not terminal, next state = same cell.
        let corner = MazeWorld.parse(["..", "S."])
        var bumper = MazeLearner(size: 2, epsilon: 0)
        bumper.maxSteps = 1
        let bumped = bumper.runEpisode(in: corner, using: &rng)
        XCTAssertEqual(bumped.steps.first?.bumped, false)
    }

    func testAllFreeCellsReachableInEveryLayout() {
        for level in 1...4 {
            for variant in 0..<2 {
                let world = MazeContent.layout(level: level, variant: variant)
                let reachable = world.safeReachable(from: world.start)
                let free = world.allCells.filter { world[$0] != .wall }
                XCTAssertEqual(Set(free), reachable, "level \(level) variant \(variant): every free cell must be reachable")
                if level == 1 || level == 3 {
                    XCTAssertNil(world.treat, "the child places the treat in levels 1 and 3")
                } else {
                    XCTAssertNotNil(world.treat)
                }
            }
        }
    }

    func testPlacementRules() {
        var challenge = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: 2)
        XCTAssertEqual(challenge.treatBudget, 1)
        XCTAssertEqual(challenge.puddleBudget, 0)
        XCTAssertFalse(challenge.canExplore, "no treat yet")
        XCTAssertEqual(challenge.tap(MazeCell(1, 0), tool: .treat), .tooClose)
        XCTAssertEqual(challenge.tap(challenge.world.start, tool: .treat), .blocked)
        XCTAssertEqual(challenge.tap(MazeCell(1, 1), tool: .treat), .blocked, "walls cannot be used")
        XCTAssertEqual(challenge.tap(MazeCell(3, 3), tool: .puddle), .budgetExhausted)
        XCTAssertEqual(challenge.tap(MazeCell(3, 3), tool: .treat), .placed)
        XCTAssertEqual(challenge.tap(MazeCell(2, 3), tool: .treat), .budgetExhausted)
        XCTAssertTrue(challenge.canExplore)
        XCTAssertTrue(challenge.isPlacedByChild(MazeCell(3, 3)))
        XCTAssertEqual(challenge.tap(MazeCell(3, 3), tool: .treat), .removed)
        XCTAssertEqual(challenge.treatsLeft, 1)
    }

    func testMapChangeForgets() {
        var challenge = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: 4)
        challenge.tap(MazeCell(3, 3), tool: .treat)
        var rng = SeededGenerator(seed: 9)
        XCTAssertNotNil(challenge.explore(using: &rng))
        XCTAssertGreaterThan(challenge.learner.episodesRun, 0)
        XCTAssertNotNil(challenge.lastBatch)
        challenge.tap(MazeCell(3, 3), tool: .treat)
        XCTAssertEqual(challenge.learner.episodesRun, 0, "changing the map resets the values")
        XCTAssertNil(challenge.lastBatch)
        XCTAssertEqual(challenge.batches, 1, "batches already spent still count")
    }

    private func solve(_ challenge: inout MazeChallenge, seed: UInt64, maxBatches: Int) -> Int? {
        var rng = SeededGenerator(seed: seed)
        for batch in 1...maxBatches {
            guard let result = challenge.explore(using: &rng) else { return nil }
            if result.solved { return batch }
        }
        return nil
    }

    func testLevelOneLearnsTheTreat() {
        for seed in 1...12 {
            var challenge = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.tap(MazeCell(3, 3), tool: .treat), .placed)
            let batches = solve(&challenge, seed: UInt64(100 + seed), maxBatches: 8)
            XCTAssertNotNil(batches, "seed \(seed): level 1 must be learned within 8 batches")
            XCTAssertTrue(challenge.isSolved)
            XCTAssertEqual(challenge.lastBatch?.greedy.outcome, .treat)
            XCTAssertGreaterThanOrEqual(challenge.scoreAccuracy, 0.6)
        }
    }

    func testLevelTwoAvoidsThePuddle() {
        for seed in 1...12 {
            var challenge = MazeContent.make(spec: specs[1], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.puddleBudget, 1)
            // Put the puddle on a cell of the short route so the learned path has to go around it.
            let puddle = seed % 2 == 0 ? MazeCell(2, 2) : MazeCell(3, 1)
            XCTAssertEqual(challenge.tap(puddle, tool: .puddle), .placed)
            XCTAssertTrue(challenge.canExplore)
            let batches = solve(&challenge, seed: UInt64(200 + seed), maxBatches: 10)
            XCTAssertNotNil(batches, "seed \(seed): level 2 must be learned within 10 batches")
            let path = challenge.lastBatch?.greedy.path ?? []
            XCTAssertFalse(path.contains(puddle), "the greedy path never steps in the puddle")
        }
    }

    func testLevelThreeWithChildTreatAndPuddles() {
        for seed in 1...8 {
            var challenge = MazeContent.make(spec: specs[2], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.treatBudget, 1)
            XCTAssertEqual(challenge.puddleBudget, 2)
            XCTAssertEqual(challenge.tap(MazeCell(5, 5), tool: .treat), .placed)
            XCTAssertTrue(challenge.canExplore, "seed \(seed): the far corner is reachable")
            let batches = solve(&challenge, seed: UInt64(300 + seed), maxBatches: 10)
            XCTAssertNotNil(batches, "seed \(seed): level 3 must be learned within 10 batches")
        }
    }

    func testMasterNeedsADetour() {
        for seed in 1...8 {
            let gate = seed % 2 == 0 ? MazeCell(3, 0) : MazeCell(0, 3)
            var straight = MazeContent.make(spec: specs[3], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertTrue(straight.requiresDetour)
            XCTAssertEqual(straight.epsilonOptions.count, 3)
            XCTAssertEqual(straight.epsilon, 0.3, accuracy: 1e-12)
            // Without a puddle the kitten learns the straight corridor: reaches the treat but no detour → not solved.
            let batches = solve(&straight, seed: UInt64(400 + seed), maxBatches: 12)
            XCTAssertNil(batches, "seed \(seed): a straight path does not satisfy the master rule")
            if let greedy = straight.lastBatch?.greedy, greedy.outcome == .treat, let treat = straight.world.treat {
                XCTAssertEqual(greedy.steps.count, straight.world.start.manhattan(to: treat))
            }

            var detour = MazeContent.make(spec: specs[3], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(detour.tap(gate, tool: .puddle), .placed)
            XCTAssertTrue(detour.canExplore, "the long way round is still safe")
            let solved = solve(&detour, seed: UInt64(500 + seed), maxBatches: 14)
            XCTAssertNotNil(solved, "seed \(seed): with the gate blocked the long safe path is learned")
            if let greedy = detour.lastBatch?.greedy, let treat = detour.world.treat {
                XCTAssertGreaterThan(greedy.steps.count, detour.world.start.manhattan(to: treat))
                XCTAssertFalse(greedy.path.contains(gate))
            }
        }
    }

    func testScoreAndHints() {
        var challenge = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: 6)
        challenge.tap(MazeCell(3, 3), tool: .treat)
        var rng = SeededGenerator(seed: 77)
        XCTAssertEqual(challenge.scoreAccuracy, 0)
        XCTAssertNotNil(challenge.hint(using: &rng))
        XCTAssertEqual(challenge.hintsUsed, 1)
        XCTAssertEqual(challenge.batches, 0, "hints are free batches")
        var solved = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: 6)
        solved.tap(MazeCell(3, 3), tool: .treat)
        XCTAssertNotNil(solve(&solved, seed: 5, maxBatches: 8))
        XCTAssertEqual(solved.scoreAccuracy, max(0.6, 1 - 0.06 * Double(max(0, solved.batches - 3))), accuracy: 1e-12)
        var exhausted = MazeContent.make(spec: specs[0], difficulty: difficulty, seed: 6)
        exhausted.tap(MazeCell(3, 3), tool: .treat)
        _ = solve(&exhausted, seed: 5, maxBatches: 8)
        XCTAssertNil(exhausted.explore(using: &rng), "no more exploring once solved")
    }

    func testDeterminism() {
        let a = MazeContent.make(spec: specs[1], difficulty: difficulty, seed: 10)
        let b = MazeContent.make(spec: specs[1], difficulty: difficulty, seed: 10)
        let c = MazeContent.make(spec: specs[1], difficulty: difficulty, seed: 11)
        XCTAssertEqual(a.world, b.world)
        XCTAssertNotEqual(a.world, c.world, "odd and even seeds use different layouts")
        XCTAssertEqual(a.episodesPerBatch, difficulty.itemCount(in: specs[1].itemRange) + 2)
    }
}
