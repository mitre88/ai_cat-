import XCTest
@testable import AICatCore

final class CurriculumTests: XCTestCase {
    func testShape() {
        XCTAssertEqual(Curriculum.scenarios.count, 10)
        XCTAssertEqual(Curriculum.scenarios.map { $0.id }, ScenarioID.allCases)
        var ids = Set<String>()
        for scenario in Curriculum.scenarios {
            XCTAssertEqual(scenario.challenges.count, 4)
            XCTAssertEqual(scenario.challenges.map { $0.index }, [1, 2, 3, 4])
            XCTAssertEqual(scenario.challenges.filter { $0.isMaster }.count, 1)
            XCTAssertEqual(scenario.titleKey.raw, "scenario.\(scenario.id.rawValue).title")
            for c in scenario.challenges {
                XCTAssertTrue(ids.insert(c.id).inserted, "duplicate id \(c.id)")
                XCTAssertEqual(c.scenario, scenario.id)
                XCTAssertTrue((1...3).contains(c.tier))
                XCTAssertEqual(c.titleKey.raw, "challenge.\(c.id).title")
                XCTAssertLessThanOrEqual(c.itemRange.lowerBound, c.itemRange.upperBound)
            }
        }
        XCTAssertEqual(Curriculum.playableScenarioIDs, [.patternGarden, .dataLibrary])
        XCTAssertEqual(Curriculum.challenge(id: "s2.c3")?.mechanic, .labeling)
        XCTAssertNil(Curriculum.challenge(id: "s2.c9"))
    }

    func testDialogScript() {
        for id in ScenarioID.allCases {
            XCTAssertNotNil(DialogScript.scenarioIntro(id), "intro for \(id)")
        }
        for moment in DialogMoment.allCases where moment != .scenarioIntro {
            XCTAssertFalse(DialogScript.lines(for: moment).isEmpty, "no lines for \(moment)")
        }
        XCTAssertEqual(DialogScript.line(for: .correct, variant: 4)?.id, DialogScript.line(for: .correct, variant: 0)?.id)
        XCTAssertEqual(Set(DialogScript.lines.map { $0.id }).count, DialogScript.lines.count, "duplicate dialog ids")
    }
}
