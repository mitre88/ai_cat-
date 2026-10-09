import XCTest
@testable import AICatCore

final class ProgressTests: XCTestCase {
    func testUnlockFlow() {
        var p = PlayerProfile(catName: "AI CAT", ageBand: .apprentice, languageCode: "es")
        XCTAssertTrue(p.isUnlocked(.patternGarden))
        XCTAssertFalse(p.isUnlocked(.dataLibrary))
        XCTAssertFalse(p.isUnlocked(.classifierWorkshop))
        let s1 = Curriculum.scenario(.patternGarden)
        XCTAssertTrue(p.isUnlocked(challenge: s1.challenges[0]))
        XCTAssertFalse(p.isUnlocked(challenge: s1.challenges[1]))

        let r1 = p.record(ChallengeResult(challengeID: "s1.c1", accuracy: 1, hintsUsed: 0, durationSeconds: 30), spec: s1.challenges[0])
        XCTAssertEqual(r1.xpGained, 100)
        XCTAssertTrue(r1.passed)
        XCTAssertEqual(p.totalXP, 100)
        XCTAssertTrue(p.isUnlocked(challenge: s1.challenges[1]))

        _ = p.record(ChallengeResult(challengeID: "s1.c2", accuracy: 0.8, hintsUsed: 1, durationSeconds: 40), spec: s1.challenges[1])
        let r3 = p.record(ChallengeResult(challengeID: "s1.c3", accuracy: 1, hintsUsed: 0, durationSeconds: 50), spec: s1.challenges[2])
        XCTAssertEqual(r3.scenarioJustCompleted, .patternGarden)
        XCTAssertEqual(r3.knowledgeUnlocked, .collar)
        XCTAssertEqual(r3.nextScenarioUnlocked, .dataLibrary)
        XCTAssertTrue(p.isCompleted(.patternGarden))
        XCTAssertTrue(p.isUnlocked(.dataLibrary))
        XCTAssertTrue(p.isUnlocked(challenge: s1.challenges[3]))
        XCTAssertEqual(p.totalXP, 100 + 160 + 300)
        XCTAssertEqual(p.completedScenarioCount, 1)

        let fail = p.record(ChallengeResult(challengeID: "s2.c1", accuracy: 0.3, hintsUsed: 0, durationSeconds: 10), spec: Curriculum.challenge(id: "s2.c1")!)
        XCTAssertFalse(fail.passed)
        XCTAssertEqual(fail.xpGained, 25)
        XCTAssertFalse(p.isPassed("s2.c1"))
    }

    func testStageUpAndCodable() throws {
        var p = PlayerProfile(catName: "Luna", ageBand: .explorer, languageCode: "en")
        let spec = Curriculum.challenge(id: "s1.c4")!
        var outcome: PlayerProfile.RecordOutcome?
        for _ in 0..<3 {
            outcome = p.record(ChallengeResult(challengeID: spec.id, accuracy: 1, hintsUsed: 0, durationSeconds: 1), spec: spec)
        }
        XCTAssertEqual(p.totalXP, 900)
        XCTAssertEqual(outcome?.stageIncreased, true)
        XCTAssertEqual(p.stage, 1)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(PlayerProfile.self, from: data)
        XCTAssertEqual(decoded, p)
    }
}
