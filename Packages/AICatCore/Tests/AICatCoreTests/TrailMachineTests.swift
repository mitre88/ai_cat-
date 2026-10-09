import XCTest
@testable import AICatCore

final class TrailMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.algorithmTrail).challenges }

    func testPrimitives() {
        let world = TrailWorld(width: 4, height: 3, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(3, 2), puddles: [TrailCell(2, 0)])
        let bump = TrailInterpreter.run([.turnLeft, .turnLeft, .forward], in: world)
        XCTAssertEqual(bump.events, [.turned(.north), .turned(.west), .bumped(at: TrailCell(0, 0))])
        XCTAssertEqual(bump.outcome, .lost)
        let splash = TrailInterpreter.run([.forward, .forward], in: world)
        XCTAssertEqual(splash.outcome, .splash)
        XCTAssertEqual(splash.events.last, .splashed(at: TrailCell(2, 0)))
        let jump = TrailInterpreter.run([.forward, .jump, .turnLeft, .repeatForward(2)], in: world)
        XCTAssertEqual(jump.outcome, .goal)
        XCTAssertEqual(jump.finalCell, TrailCell(3, 2))
        XCTAssertEqual(jump.events[1], .jumped(over: TrailCell(2, 0), to: TrailCell(3, 0)))
        let conditional = TrailInterpreter.run([.forward, .ifPuddleAhead, .ifPuddleAhead, .turnLeft, .forward, .forward], in: world)
        XCTAssertEqual(conditional.outcome, .goal, "the second if does nothing because no puddle is ahead")
        let endless = TrailInterpreter.run(Array(repeating: .repeatForward(9), count: 10), in: TrailWorld(width: 100, height: 1, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(99, 0), puddles: []))
        XCTAssertEqual(endless.outcome, .tooLong)
        XCTAssertEqual(TrailInterpreter.cost(of: [.forward, .ifPuddleAhead, .repeatForward(3)]), 5)
    }

    func testEveryLayoutHasAValidSolutionWithinBudget() {
        for spec in specs {
            for seed: UInt64 in 0...3 {
                var c = TrailContent.make(spec: spec, difficulty: AdaptiveDifficulty(band: .apprentice), seed: seed)
                XCTAssertLessThanOrEqual(TrailInterpreter.cost(of: c.solution), c.maxCost, "\(spec.id) seed \(seed)")
                for block in c.solution {
                    XCTAssertTrue(c.palette.contains(block.kind), "\(spec.id): solution uses only palette blocks")
                    XCTAssertTrue(c.append(block), "\(spec.id) seed \(seed): budget allows the solution")
                }
                let run = c.run()
                XCTAssertEqual(run.outcome, .goal, "\(spec.id) seed \(seed): \(run.events)")
                XCTAssertTrue(c.isSolved)
                XCTAssertEqual(c.scoreAccuracy, 1, accuracy: 1e-12)
                XCTAssertTrue(c.world.contains(c.world.goal))
                XCTAssertFalse(c.world.isPuddle(c.world.start))
            }
        }
    }

    func testEditingHintsAndScoring() {
        var c = TrailContent.make(spec: specs[2], difficulty: AdaptiveDifficulty(band: .explorer), seed: 0)
        XCTAssertEqual(c.maxCost, 3)
        XCTAssertTrue(c.append(.forward))
        XCTAssertTrue(c.append(.forward))
        XCTAssertTrue(c.append(.forward))
        XCTAssertFalse(c.append(.forward), "budget exhausted")
        XCTAssertFalse(c.append(.jump), "jump is not in this palette")
        XCTAssertEqual(c.run().outcome, .lost)
        XCTAssertEqual(c.runs, 1)
        c.clear()
        XCTAssertEqual(c.hint(), .repeatForward(5))
        XCTAssertTrue(c.append(.repeatForward(5)))
        XCTAssertNil(c.hint(), "program already complete")
        XCTAssertEqual(c.run().outcome, .goal)
        XCTAssertEqual(c.scoreAccuracy, 0.85, accuracy: 1e-12)
        c.removeLast()
        XCTAssertEqual(c.program.count, 1, "solved programs are frozen")
        XCTAssertFalse(c.append(.forward))
        XCTAssertEqual(c.hintsUsed, 2)
    }
}
