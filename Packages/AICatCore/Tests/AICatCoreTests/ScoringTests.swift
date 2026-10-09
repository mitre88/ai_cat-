import XCTest
@testable import AICatCore

final class ScoringTests: XCTestCase {
    func testGoldenXP() {
        for c in GoldenValues.xpCases {
            XCTAssertEqual(Scoring.xp(tier: c.tier, accuracy: c.accuracy), c.xp, "tier \(c.tier) acc \(c.accuracy)")
            XCTAssertEqual(Scoring.stars(accuracy: c.accuracy), c.stars)
        }
    }

    func testPassThreshold() {
        XCTAssertTrue(Scoring.isPassed(accuracy: 0.6))
        XCTAssertFalse(Scoring.isPassed(accuracy: 0.59))
    }
}
