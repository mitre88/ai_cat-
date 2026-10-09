import XCTest
@testable import AICatCore

final class FairnessMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.fairScale).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testBiasHuntContentAndPicks() {
        for seed in 1...12 {
            var challenge = FairnessContent.makeBiasHunt(spec: specs[0], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.count(challenge.missingCoat), 0, "the missing coat has no examples")
            let zeroCoats = CatCoat.allCases.filter { challenge.count($0) == 0 }
            XCTAssertEqual(zeroCoats, [challenge.missingCoat], "exactly one coat is missing")
            XCTAssertEqual(challenge.dataset.count, max(difficulty.itemCount(in: specs[0].itemRange), 5))
            XCTAssertEqual(challenge.testResults.count, 8)
            XCTAssertTrue(challenge.testResults.filter { $0.coat == challenge.missingCoat }.allSatisfy { !$0.recognized })
            let plentiful = CatCoat.allCases.first { challenge.count($0) >= 2 }!
            XCTAssertTrue(challenge.testResults.filter { $0.coat == plentiful }.allSatisfy { $0.recognized })
            let wrong = CatCoat.allCases.first { $0 != challenge.missingCoat }!
            XCTAssertFalse(challenge.pick(wrong))
            XCTAssertFalse(challenge.isSolved)
            XCTAssertEqual(challenge.scoreAccuracy, 0)
            XCTAssertTrue(challenge.pick(challenge.missingCoat))
            XCTAssertTrue(challenge.isSolved)
            XCTAssertEqual(challenge.scoreAccuracy, 0.75, accuracy: 1e-12)
            XCTAssertFalse(challenge.pick(wrong), "after solving, picks do nothing and still report the truth")
            XCTAssertEqual(challenge.picks.count, 2)
        }
    }

    func testBalanceFlow() {
        for seed in 1...10 {
            var challenge = FairnessContent.makeBalance(spec: specs[1], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.target, 2)
            XCTAssertFalse(challenge.isSolved)
            XCTAssertGreaterThan(challenge.fairnessGap, 0.5)
            for coat in CatCoat.allCases {
                let available = challenge.pool.filter { $0.coat == coat }.count + challenge.count(coat)
                XCTAssertGreaterThanOrEqual(available, challenge.target, "seed \(seed): enough \(coat) cards exist")
            }
            // Add only what is needed, lowest coats first.
            var needed = 0
            for coat in CatCoat.allCases {
                while challenge.count(coat) < challenge.target {
                    let card = challenge.pool.first { $0.coat == coat }!
                    XCTAssertTrue(challenge.add(card.id))
                    needed += 1
                }
            }
            XCTAssertTrue(challenge.isSolved)
            XCTAssertEqual(challenge.adds, challenge.neededAdds)
            XCTAssertEqual(needed, challenge.neededAdds)
            XCTAssertEqual(challenge.fairnessGap, 0, accuracy: 1e-12)
            XCTAssertEqual(challenge.scoreAccuracy, 1, accuracy: 1e-12)
            XCTAssertFalse(challenge.add(challenge.pool.first?.id ?? ""), "nothing moves once solved")
        }
        var wasteful = FairnessContent.makeBalance(spec: specs[1], difficulty: difficulty, seed: 3)
        let plentiful = CatCoat.allCases.max { wasteful.count($0) < wasteful.count($1) }!
        let extra = wasteful.pool.first { $0.coat == plentiful }!
        XCTAssertTrue(wasteful.add(extra.id))
        XCTAssertTrue(wasteful.isFromPool(extra.id))
        XCTAssertTrue(wasteful.remove(extra.id), "pool cards can go back")
        XCTAssertFalse(wasteful.remove(wasteful.dataset.first { !wasteful.isFromPool($0.id) }!.id), "the original cards stay")
        XCTAssertTrue(wasteful.add(extra.id))
        for coat in CatCoat.allCases {
            while wasteful.count(coat) < wasteful.target {
                wasteful.add(wasteful.pool.first { $0.coat == coat }!.id)
            }
        }
        XCTAssertTrue(wasteful.isSolved)
        XCTAssertEqual(wasteful.scoreAccuracy, 0.95, accuracy: 1e-12, "one unnecessary card costs 0.05")
    }

    func testPrivacyDecisions() {
        var challenge = FairnessContent.makePrivacy(spec: specs[2], difficulty: difficulty, seed: 8)
        XCTAssertGreaterThanOrEqual(challenge.items.count, 4)
        XCTAssertTrue(challenge.items.contains { $0.shouldKeep })
        XCTAssertTrue(challenge.items.contains { !$0.shouldKeep })
        XCTAssertEqual(Set(challenge.items.map(\.id)).count, challenge.items.count)
        XCTAssertEqual(challenge.scoreAccuracy, 0)
        for item in challenge.items {
            challenge.decide(item.id, keep: item.shouldKeep)
        }
        XCTAssertTrue(challenge.isComplete)
        XCTAssertEqual(challenge.scoreAccuracy, 1, accuracy: 1e-12)
        var half = FairnessContent.makePrivacy(spec: specs[2], difficulty: difficulty, seed: 8)
        for item in half.items { half.decide(item.id, keep: true) }
        XCTAssertEqual(half.correctCount, half.items.filter(\.shouldKeep).count)
        let favourite = FairnessContent.privacyBank.first { $0.id == "favorite_colour" }!
        XCTAssertFalse(favourite.shouldKeep, "not private, but the game does not need it: do not keep")
    }

    func testJudgeCases() {
        for seed in 1...8 {
            var challenge = FairnessContent.makeJudge(spec: specs[3], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertGreaterThanOrEqual(challenge.cases.count, 2)
            XCTAssertLessThanOrEqual(challenge.cases.count, 4)
            XCTAssertEqual(Set(challenge.cases.map(\.cause)).count, challenge.cases.count, "cases cover different causes")
            for item in challenge.cases {
                challenge.answerCause(item.id, item.cause)
                challenge.answerFix(item.id, FairFix.allCases.first { $0 != item.fix }!)
                challenge.answerFix(item.id, item.fix)   // answers are final
            }
            XCTAssertTrue(challenge.isComplete)
            XCTAssertEqual(challenge.correctCount, challenge.cases.count)
            XCTAssertEqual(challenge.scoreAccuracy, 0.5, accuracy: 1e-12)
        }
    }
}
