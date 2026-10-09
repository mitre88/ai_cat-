import XCTest
@testable import AICatCore

final class ScatterMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.classifierWorkshop).challenges }

    func testModelsPredict() {
        let points = [ScatterPoint(id: "a", x: 0.2, y: 0.5, label: 0), ScatterPoint(id: "b", x: 0.8, y: 0.5, label: 1)]
        XCTAssertEqual(ScatterLearner.predict(.threshold(x: 0.5), x: 0.1, y: 0.9, points: points), 0)
        XCTAssertEqual(ScatterLearner.predict(.threshold(x: 0.5), x: 0.9, y: 0.1, points: points), 1)
        // Polarity follows the data: flipping the labels flips the sides.
        let flipped = [ScatterPoint(id: "a", x: 0.2, y: 0.5, label: 1), ScatterPoint(id: "b", x: 0.8, y: 0.5, label: 0)]
        XCTAssertEqual(ScatterLearner.predict(.threshold(x: 0.5), x: 0.1, y: 0.9, points: flipped), 1)
        let line = ScatterModel.line(x1: 0, y1: 0, x2: 1, y2: 1)
        let diagonal = [ScatterPoint(id: "a", x: 0.2, y: 0.8, label: 0), ScatterPoint(id: "b", x: 0.8, y: 0.2, label: 1)]
        XCTAssertEqual(ScatterLearner.accuracy(line, points: diagonal), 1, accuracy: 1e-12)
        let centroids = ScatterModel.centroids([ScatterCentroid(x: 0.2, y: 0.2, label: 0), ScatterCentroid(x: 0.8, y: 0.8, label: 1)])
        XCTAssertEqual(ScatterLearner.predict(centroids, x: 0.3, y: 0.1, points: []), 0)
        XCTAssertEqual(ScatterLearner.predict(centroids, x: 0.9, y: 0.6, points: []), 1)
        let means = ScatterLearner.centroids(of: diagonal, classes: 2)
        XCTAssertEqual(means[0].x, 0.2, accuracy: 1e-12)
        XCTAssertEqual(means[1].y, 0.2, accuracy: 1e-12)
    }

    func testEveryLevelIsSolvableByTheIdealModel() {
        for spec in specs {
            for band in AgeBand.allCases {
                for seed: UInt64 in 1...5 {
                    var c = ScatterContent.make(spec: spec, difficulty: AdaptiveDifficulty(band: band), seed: seed)
                    XCTAssertFalse(c.isSolved, "\(spec.id) should start unsolved")
                    XCTAssertEqual(c.testPoints.count, c.classes * 2)
                    if c.allowsFlagging {
                        for p in c.points where p.isOutlier { c.toggleFlag(pointID: p.id) }
                    }
                    let ideal = ScatterContent.idealModel(for: c)
                    switch ideal {
                    case .threshold(let x): c.setThreshold(x)
                    case .line(let x1, let y1, let x2, let y2): c.setLine(x1: x1, y1: y1, x2: x2, y2: y2)
                    case .centroids(let cs): for k in cs { c.moveCentroid(label: k.label, x: k.x, y: k.y) }
                    }
                    XCTAssertTrue(c.isSolved, "\(spec.id) seed \(seed) band \(band): ideal model reaches target (accuracy \(c.accuracy))")
                    XCTAssertGreaterThanOrEqual(c.testAccuracy, 0.5)
                    XCTAssertGreaterThan(c.adjustments, 0)
                }
            }
        }
    }

    func testFlaggingAndHints() {
        var c = ScatterContent.make(spec: specs[3], difficulty: AdaptiveDifficulty(band: .master), seed: 2)
        XCTAssertTrue(c.allowsFlagging)
        let outliers = c.points.filter { $0.isOutlier }
        XCTAssertFalse(outliers.isEmpty)
        let honest = c.points.first { !$0.isOutlier }!
        c.toggleFlag(pointID: honest.id)
        XCTAssertEqual(c.wronglyFlaggedCount, 1)
        c.toggleFlag(pointID: honest.id)
        XCTAssertEqual(c.wronglyFlaggedCount, 0)
        let before = c.accuracy
        for _ in 0..<6 { c.applyHint() }
        XCTAssertEqual(c.hintsUsed, 6)
        for p in outliers { c.toggleFlag(pointID: p.id) }
        XCTAssertGreaterThanOrEqual(c.accuracy, before)
        var level1 = ScatterContent.make(spec: specs[0], difficulty: AdaptiveDifficulty(band: .explorer), seed: 9)
        XCTAssertFalse(level1.toggleFlag(pointID: level1.points[0].id), "flagging is only allowed when outliers exist")
        level1.setThreshold(2)
        if case .threshold(let x) = level1.model { XCTAssertEqual(x, 1) } else { XCTFail() }
    }
}
