import XCTest
@testable import AICatCore

final class RuleLearnerTests: XCTestCase {
    private let examples: [Example] = [
        Example(attributes: ["color": "red", "shape": "round"], label: "A"),
        Example(attributes: ["color": "red", "shape": "long"], label: "A"),
        Example(attributes: ["color": "green", "shape": "round"], label: "B"),
        Example(attributes: ["color": "green", "shape": "long"], label: "B"),
        Example(attributes: ["color": "red", "shape": "round"], label: "A"),
        Example(attributes: ["color": "green", "shape": "round"], label: "B"),
    ]

    func testEntropyGolden() {
        for c in GoldenValues.entropyCases {
            XCTAssertEqual(RuleLearner.entropy(c.labels), c.entropy, accuracy: 1e-12, "\(c.labels)")
        }
    }

    func testInformationGainGolden() {
        XCTAssertEqual(RuleLearner.informationGain(examples, attribute: "color"), GoldenValues.informationGainColor, accuracy: 1e-12)
        XCTAssertEqual(RuleLearner.informationGain(examples, attribute: "shape"), GoldenValues.informationGainShape, accuracy: 1e-12)
    }

    func testLearnsUniqueStump() {
        let learned = RuleLearner.learn(examples, attributes: ["color", "shape"], conjunctionLabels: nil)
        guard case .stump(let stump)? = learned else { return XCTFail("expected a stump") }
        XCTAssertEqual(stump.attribute, "color")
        XCTAssertEqual(stump.predict(["color": "red", "shape": "long"]), "A")
        XCTAssertNil(stump.predict(["color": "purple"]))
    }

    func testAmbiguousExamplesDoNotCommit() {
        let correlated: [Example] = [
            Example(attributes: ["color": "red", "shape": "round"], label: "A"),
            Example(attributes: ["color": "green", "shape": "long"], label: "B"),
            Example(attributes: ["color": "red", "shape": "round"], label: "A"),
        ]
        XCTAssertNil(RuleLearner.learn(correlated, attributes: ["color", "shape"], conjunctionLabels: nil))
        XCTAssertEqual(RuleLearner.stumpCandidates(correlated, attributes: ["color", "shape"]).count, 2)
        XCTAssertNil(RuleLearner.learn(Array(examples.prefix(2)), attributes: ["color"], conjunctionLabels: nil), "below minimum examples")
    }

    func testLearnsConjunctionOnlyWhenStumpsAreRefuted() {
        let truth = ConjunctionRule(attribute1: "color", value1: "red", attribute2: "shape", value2: "round", positiveLabel: "A", negativeLabel: "B")
        let fruits: [[String: String]] = [
            ["color": "red", "shape": "round"], ["color": "red", "shape": "long"],
            ["color": "green", "shape": "round"], ["color": "green", "shape": "long"],
        ]
        let all = fruits.map { Example(attributes: $0, label: truth.predict($0)) }
        let learned = RuleLearner.learn(all, attributes: ["color", "shape"], conjunctionLabels: ("A", "B"))
        guard case .conjunction(let rule)? = learned else { return XCTFail("expected a conjunction") }
        XCTAssertEqual(rule, truth)
        // While a single-attribute rule (colour) still explains the examples → no commitment.
        let partial = [all[0], all[2], all[0]]
        XCTAssertNil(RuleLearner.learn(partial, attributes: ["color", "shape"], conjunctionLabels: ("A", "B")))
    }
}
