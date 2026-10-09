import XCTest
@testable import AICatCore

final class GrowthModelTests: XCTestCase {
    func testGoldenGrowthTable() {
        for g in GoldenValues.growth {
            XCTAssertEqual(GrowthModel.normalizedGrowth(xp: g.xp), g.normalized, accuracy: 1e-12, "xp \(g.xp)")
            XCTAssertEqual(GrowthModel.stage(xp: g.xp), g.stage, "stage at xp \(g.xp)")
            let m = CatMorphology.forXP(g.xp)
            XCTAssertEqual(m.bodyLength, g.bodyLength, accuracy: 1e-12)
            XCTAssertEqual(m.headRadiusRatio, g.headRadiusRatio, accuracy: 1e-12)
            XCTAssertEqual(m.legLength, g.legLength, accuracy: 1e-12)
            XCTAssertEqual(m.earScale, g.earScale, accuracy: 1e-12)
            XCTAssertEqual(m.tailLength, g.tailLength, accuracy: 1e-12)
            XCTAssertEqual(m.eyeRadiusRatio, g.eyeRadiusRatio, accuracy: 1e-12)
        }
    }

    func testStageBoundaries() {
        for s in 0...10 {
            let boundary = GoldenValues.xpForStage[s]
            XCTAssertEqual(GrowthModel.xpForStage(s), boundary, accuracy: 1e-9)
            XCTAssertEqual(GrowthModel.stage(xp: boundary), s)
            if s > 0 { XCTAssertEqual(GrowthModel.stage(xp: boundary - 1), s - 1) }
        }
        XCTAssertEqual(GrowthModel.stage(xp: 9000), 10)
        XCTAssertEqual(GrowthModel.stage(xp: -5), 0)
    }

    func testMonotonicAndBounded() {
        var previous = -1.0
        for i in 0...200 {
            let g = GrowthModel.normalizedGrowth(xp: Double(i) * 50)
            XCTAssertGreaterThanOrEqual(g, previous)
            XCTAssertGreaterThanOrEqual(g, 0)
            XCTAssertLessThanOrEqual(g, 1)
            previous = g
        }
    }

    func testProgressWithinStage() {
        XCTAssertEqual(GrowthModel.progressWithinStage(xp: 360), 0.5, accuracy: 1e-12)
        XCTAssertEqual(GrowthModel.progressWithinStage(xp: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(GrowthModel.progressWithinStage(xp: 7200), 1, accuracy: 1e-12)
    }

    func testMorphologyEndpoints() {
        XCTAssertEqual(CatMorphology.interpolated(growth: 0), CatMorphology.kitten)
        XCTAssertEqual(CatMorphology.interpolated(growth: 1), CatMorphology.adult)
        let mid = CatMorphology.interpolated(growth: 0.5)
        XCTAssertGreaterThan(mid.standingHeight, CatMorphology.kitten.standingHeight)
        XCTAssertLessThan(mid.standingHeight, CatMorphology.adult.standingHeight)
    }
}
