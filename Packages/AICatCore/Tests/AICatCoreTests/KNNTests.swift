import XCTest
@testable import AICatCore

final class KNNTests: XCTestCase {
    private var classifier: KNNClassifier {
        KNNClassifier(k: 3, examples: GoldenValues.knnExamples.map { LabeledFeature(features: FeatureVector($0.features), label: $0.label) })
    }

    func testGoldenPredictions() {
        for q in GoldenValues.knnQueries {
            XCTAssertEqual(classifier.predict(FeatureVector(q.features))?.label, q.label, "\(q.features)")
        }
    }

    func testAccuracyOnTrainingSet() {
        let tests = GoldenValues.knnExamples.map { LabeledFeature(features: FeatureVector($0.features), label: $0.label) }
        XCTAssertEqual(classifier.accuracy(on: tests), 1, accuracy: 1e-12)
        XCTAssertEqual(KNNClassifier(k: 3, examples: []).accuracy(on: tests), 0)
        XCTAssertNil(KNNClassifier(k: 3, examples: []).predict(FeatureVector([0, 0, 0])))
    }

    func testConfidence() {
        let p = classifier.predict(FeatureVector([0.3, 0.9, 0.2]))
        XCTAssertEqual(p?.confidence ?? 0, 1, accuracy: 1e-12)
    }
}
