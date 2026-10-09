import XCTest
@testable import AICatCore

final class SortingMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.patternGarden).challenges }

    func testGenerationInvariants() {
        for spec in specs {
            for band in AgeBand.allCases {
                for seed: UInt64 in 1...6 {
                    let c = SortingContent.make(spec: spec, difficulty: AdaptiveDifficulty(band: band), seed: seed)
                    XCTAssertGreaterThanOrEqual(c.fruits.count, spec.itemRange.lowerBound, "\(spec.id)")
                    XCTAssertEqual(Set(c.fruits.map { $0.id }).count, c.fruits.count, "unique fruit ids")
                    XCTAssertEqual(c.baskets.count, 2)
                    let perBasket = Dictionary(grouping: c.fruits, by: { c.rule.basket(for: $0) })
                    XCTAssertEqual(Set(perBasket.keys), Set(c.baskets.map { $0.id }), "\(spec.id) seed \(seed): every basket receives fruit")
                    XCTAssertEqual(c.ruleIsStated, spec.index == 1)
                    XCTAssertEqual(c.activeAttributes.count, spec.param("attributes", default: 1))
                    // The true rule must be the unique hypothesis over the full fruit set.
                    let all = c.fruits.map { Example(attributes: $0.attributes, label: c.rule.basket(for: $0)) }
                    let learned = RuleLearner.learn(all, attributes: c.activeAttributes.map { $0.rawValue }, conjunctionLabels: c.rule.conjunctionLabels)
                    XCTAssertNotNil(learned, "\(spec.id) seed \(seed) band \(band): rule must be learnable from all fruits")
                    for fruit in c.fruits {
                        XCTAssertEqual(learned?.predict(fruit.attributes), c.rule.basket(for: fruit))
                    }
                }
            }
        }
    }

    func testPlayThroughWithAICat() {
        let spec = specs[0]
        var c = SortingContent.make(spec: spec, difficulty: AdaptiveDifficulty(band: .explorer), seed: 42)
        XCTAssertEqual(c.accuracy, 1)
        // One mistake first.
        let first = c.fruits[0]
        let expected = c.expectedBasket(for: first)
        let wrong = c.baskets.first(where: { $0.id != expected })!.id
        XCTAssertEqual(c.place(fruitID: first.id, in: wrong), .wrong(expected: expected))
        XCTAssertEqual(c.remaining.count, c.fruits.count)
        XCTAssertEqual(c.place(fruitID: first.id, in: expected), .correct)
        XCTAssertEqual(c.place(fruitID: first.id, in: expected), .ignored)
        XCTAssertEqual(c.accuracy, 0.5, accuracy: 1e-12)
        // Teach until AI CAT learns, then it finishes.
        var learned: LearnedRule?
        for fruit in c.fruits where c.placements[fruit.id] == nil {
            XCTAssertEqual(c.place(fruitID: fruit.id, in: c.expectedBasket(for: fruit)), .correct)
            learned = c.letAICatLearn()
            if learned != nil { break }
        }
        XCTAssertNotNil(learned, "AI CAT should learn a two-colour rule from a few examples")
        let moves = c.aiCatSortsRemaining()
        XCTAssertTrue(c.isComplete)
        XCTAssertEqual(moves.count, c.aiSortedIDs.count)
        for move in moves { XCTAssertEqual(move.basketID, c.expectedBasket(for: move.fruit)) }
    }

    func testHintsAndCodable() throws {
        var c = SortingContent.make(spec: specs[2], difficulty: AdaptiveDifficulty(band: .master), seed: 7)
        let hint = c.useHint()
        XCTAssertNotNil(hint)
        XCTAssertEqual(c.hintsUsed, 1)
        XCTAssertEqual(hint?.basketID, c.expectedBasket(for: hint!.fruit))
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(SortingChallenge.self, from: data)
        XCTAssertEqual(decoded.fruits, c.fruits)
        XCTAssertEqual(decoded.rule, c.rule)
        XCTAssertFalse(c.rule.statements.isEmpty)
    }
}
