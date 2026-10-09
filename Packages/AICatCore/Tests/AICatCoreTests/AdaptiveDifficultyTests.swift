import XCTest
@testable import AICatCore

final class AdaptiveDifficultyTests: XCTestCase {
    func testGoldenTrace() {
        var d = AdaptiveDifficulty(band: .apprentice)
        XCTAssertEqual(d.value, 0.45, accuracy: 1e-12)
        for (input, expected) in zip(GoldenValues.difficultyInputs, GoldenValues.difficultyApprenticeTrace) {
            d.update(accuracy: input)
            XCTAssertEqual(d.value, expected, accuracy: 1e-12)
        }
    }

    func testClamping() {
        var d = AdaptiveDifficulty(band: .master)
        for _ in 0..<200 { d.update(accuracy: 1) }
        XCTAssertEqual(d.value, 1)
        for _ in 0..<200 { d.update(accuracy: 0) }
        XCTAssertEqual(d.value, 0)
    }

    func testItemCounts() {
        for c in GoldenValues.itemCounts {
            XCTAssertEqual(AdaptiveDifficulty(value: c.d).itemCount(in: c.lo...c.hi), c.n, "lo \(c.lo) hi \(c.hi) d \(c.d)")
        }
    }

    func testBandsStartDifferently() {
        XCTAssertLessThan(AgeBand.explorer.initialDifficulty, AgeBand.apprentice.initialDifficulty)
        XCTAssertLessThan(AgeBand.apprentice.initialDifficulty, AgeBand.master.initialDifficulty)
        XCTAssertEqual(AgeBand.forAge(6), .explorer)
        XCTAssertEqual(AgeBand.forAge(9), .apprentice)
        XCTAssertEqual(AgeBand.forAge(12), .master)
    }
}
