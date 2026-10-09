import XCTest
@testable import AICatCore

final class VisionMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.catEyes).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testPixelImageBasics() {
        let image = PixelImage.parse(["090", "000", "009"])
        XCTAssertEqual(image.width, 3)
        XCTAssertEqual(image[PixelPoint(1, 0)], 9)
        XCTAssertEqual(image.brightestPixels, [PixelPoint(1, 0), PixelPoint(2, 2)])
        XCTAssertEqual(image.gradient(at: PixelPoint(0, 0)), 9)
        XCTAssertEqual(image.gradient(at: PixelPoint(0, 2)), 0)
        XCTAssertEqual(image.edges(threshold: 10), [])
        XCTAssertEqual(image.edges(threshold: 0).count, 9)
        XCTAssertTrue(VisionContent.shapeIDs.allSatisfy { VisionContent.image($0).width == 10 && VisionContent.image($0).height == 10 })
    }

    func testPixelChallenge() {
        for seed in 1...8 {
            var challenge = VisionContent.makePixels(spec: specs[0], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.image.maxValue, 9)
            XCTAssertGreaterThanOrEqual(challenge.targets.count, 1)
            XCTAssertLessThanOrEqual(challenge.targets.count, 3)
            let target = challenge.targets.first!
            XCTAssertTrue(challenge.tap(target), "the pixel is bright, but...")
            XCTAssertTrue(challenge.picks.isEmpty, "...taps only count at full zoom")
            challenge.setZoom(9)
            XCTAssertEqual(challenge.zoom, PixelChallenge.maxZoom)
            let dark = challenge.image.allPoints.first { challenge.image[$0] == 0 }!
            XCTAssertFalse(challenge.tap(dark))
            XCTAssertEqual(challenge.wrongPicks, 1)
            for point in challenge.targets { challenge.tap(point) }
            XCTAssertTrue(challenge.isSolved)
            XCTAssertEqual(challenge.scoreAccuracy, 0.85, accuracy: 1e-12)
        }
    }

    func testEdgeThresholdHasASweetSpot() {
        for seed in 1...12 {
            var challenge = VisionContent.makeEdges(spec: specs[1], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertFalse(challenge.boundary.isEmpty)
            XCTAssertLessThan(challenge.f1, EdgeChallenge.targetF1, "threshold 0 marks everything")
            var solvedAt: [Int] = []
            for threshold in 0...9 {
                challenge.setThreshold(threshold)
                if challenge.isSolved { solvedAt.append(threshold) }
            }
            XCTAssertFalse(solvedAt.isEmpty, "seed \(seed): some threshold matches the outline")
            XCTAssertTrue(solvedAt.contains(4), "seed \(seed): the inter-class gap (≥ 4) is the natural threshold")
            XCTAssertFalse(solvedAt.contains(1), "seed \(seed): a tiny threshold also marks the shading")
            challenge.setThreshold(9)
            XCTAssertFalse(challenge.isSolved, "a huge threshold finds nothing")
            challenge.setThreshold(4)
            XCTAssertTrue(challenge.isSolved)
            XCTAssertEqual(challenge.adjustments, 10, "setting the same threshold again is not an adjustment")
            XCTAssertEqual(challenge.scoreAccuracy, max(0.7, 1 - 0.03 * 4), accuracy: 1e-12)
        }
    }

    func testShapeMatching() {
        for seed in 1...12 {
            var challenge = VisionContent.makeShapes(spec: specs[2], difficulty: difficulty, seed: UInt64(seed))
            XCTAssertEqual(challenge.templates.count, 4)
            XCTAssertGreaterThanOrEqual(challenge.rounds.count, 3)
            for round in challenge.rounds {
                let best = round.clues.max { $0.value < $1.value }!
                XCTAssertEqual(best.key, round.answerID, "seed \(seed): the true template keeps the most clues")
                XCTAssertNotEqual(round.query, challenge.templates.first { $0.id == round.answerID }!.image, "the query is noisy")
            }
            while let round = challenge.current {
                XCTAssertEqual(challenge.pick(round.answerID), true)
            }
            XCTAssertTrue(challenge.isComplete)
            XCTAssertEqual(challenge.scoreAccuracy, 1, accuracy: 1e-12)
            XCTAssertNil(challenge.pick("fish"))
        }
    }

    func testLiveChecks() {
        var challenge = VisionContent.makeLive(spec: specs[3], difficulty: difficulty, seed: 1)
        XCTAssertGreaterThanOrEqual(challenge.required, 3)
        challenge.record(label: "cat", confidence: 0.9, agreed: true)
        challenge.record(label: "dog", confidence: 1.7, agreed: false)
        XCTAssertEqual(challenge.checks.last?.confidence, 1)
        XCTAssertEqual(challenge.disagreements, 1)
        XCTAssertFalse(challenge.isSolved)
        while !challenge.isSolved { challenge.record(label: "cup", confidence: 0.4, agreed: true) }
        XCTAssertEqual(challenge.checks.count, challenge.required)
        XCTAssertEqual(challenge.scoreAccuracy, 1)
    }
}
