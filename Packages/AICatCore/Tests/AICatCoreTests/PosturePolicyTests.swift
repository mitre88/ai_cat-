import XCTest
@testable import AICatCore

final class PosturePolicyTests: XCTestCase {
    private let size = CGSize(width: 800, height: 1100)

    func testFlatAndClosed() {
        XCTAssertEqual(PosturePolicy.posture(size: size, activeDivision: nil, isRegularWidth: true), .world)
        XCTAssertEqual(PosturePolicy.posture(size: size, activeDivision: nil, isRegularWidth: false), .pocket)
        XCTAssertEqual(PosturePolicy.posture(size: size, activeDivision: .zero, isRegularWidth: false), .pocket, "an empty region is not a fold")
    }

    func testTabletopAndBook() {
        let horizontal = CGRect(x: 0, y: 540, width: 800, height: 20)
        let vertical = CGRect(x: 390, y: 0, width: 20, height: 1100)
        XCTAssertEqual(PosturePolicy.posture(size: size, activeDivision: horizontal, isRegularWidth: true), .lab(division: horizontal))
        XCTAssertEqual(PosturePolicy.posture(size: size, activeDivision: vertical, isRegularWidth: true), .book(division: vertical))
        XCTAssertTrue(StagePosture.lab(division: horizontal).isFolded)
        XCTAssertFalse(StagePosture.world.isFolded)
    }

    func testOpennessFromHingeAngle() {
        XCTAssertEqual(PostureInfo(posture: .world, hingeAngleDegrees: 180, containerSize: size).openness, 1, accuracy: 1e-9)
        XCTAssertEqual(PostureInfo(posture: .lab(division: .zero), hingeAngleDegrees: 135, containerSize: size).openness, 0.5, accuracy: 1e-9)
        XCTAssertEqual(PostureInfo(posture: .pocket, hingeAngleDegrees: 30, containerSize: size).openness, 0, accuracy: 1e-9)
        XCTAssertEqual(PostureInfo.fallback.openness, 1, accuracy: 1e-9)
        let info = PosturePolicy.info(size: size, activeDivision: nil, isRegularWidth: false, hingeAngleDegrees: nil)
        XCTAssertEqual(info.posture, .pocket)
        XCTAssertEqual(info.containerSize, size)
    }
}
