import XCTest
@testable import AICatCore

final class LabelingMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.dataLibrary).challenges }

    func testGenerationInvariants() {
        for spec in specs {
            for band in AgeBand.allCases {
                for seed: UInt64 in 1...4 {
                    let c = LabelingContent.make(spec: spec, difficulty: AdaptiveDifficulty(band: band), seed: seed)
                    XCTAssertGreaterThanOrEqual(c.cards.count, spec.itemRange.lowerBound)
                    XCTAssertEqual(c.species.count, spec.param("species", default: 2))
                    XCTAssertEqual(c.testSet.count, c.species.count * 3)
                    XCTAssertEqual(c.trapIDs.count, min(spec.param("traps", default: 0), c.cards.count / 3))
                    for id in c.trapIDs { XCTAssertFalse(c.isCorrectlyLabeled(c.card(id: id)!)) }
                    XCTAssertEqual(c.isComplete, false)
                    for card in c.cards { XCTAssertTrue(c.species.contains(card.species)) }
                }
            }
        }
    }

    func testLabelingRaisesAccuracyAndTrapsLowerIt() {
        var c = LabelingContent.make(spec: specs[2], difficulty: AdaptiveDifficulty(band: .apprentice), seed: 3)
        XCTAssertEqual(c.trapIDs.count, 1)
        let withTrap = c.aiAccuracy
        for card in c.cards where !c.isCorrectlyLabeled(card) {
            XCTAssertEqual(c.label(cardID: card.id, as: card.species), .correct)
        }
        XCTAssertTrue(c.isComplete)
        XCTAssertTrue(c.trapIDs.isEmpty)
        XCTAssertGreaterThanOrEqual(c.aiAccuracy, withTrap)
        XCTAssertGreaterThanOrEqual(c.aiAccuracy, 0.66, "clean labels should make AI CAT accurate")
        XCTAssertEqual(c.childAccuracy, 1)
    }

    func testWrongLabelsStickUntilFixed() {
        var c = LabelingContent.make(spec: specs[0], difficulty: AdaptiveDifficulty(band: .explorer), seed: 9)
        let card = c.cards[0]
        let wrong = c.species.first(where: { $0 != card.species })!
        XCTAssertEqual(c.label(cardID: card.id, as: wrong), .wrong(expected: card.species))
        XCTAssertEqual(c.wronglyLabeled.map { $0.id }, [card.id])
        XCTAssertEqual(c.label(cardID: card.id, as: wrong), .ignored)
        XCTAssertEqual(c.label(cardID: card.id, as: card.species), .correct)
        XCTAssertTrue(c.wronglyLabeled.isEmpty)
        XCTAssertEqual(c.childAccuracy, 0.5, accuracy: 1e-12)
        XCTAssertNotNil(c.useHint())
    }
}
