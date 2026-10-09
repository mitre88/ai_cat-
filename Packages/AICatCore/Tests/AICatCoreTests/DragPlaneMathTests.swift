import XCTest
@testable import AICatCore

final class DragPlaneMathTests: XCTestCase {
    func testRayPlaneIntersection() {
        let hit = DragPlaneMath.intersect(rayOrigin: [0, 1, 0], rayDirection: [0, -1, 0], planePoint: [0, 0, 0], planeNormal: [0, 1, 0])
        XCTAssertEqual(hit, SIMD3<Float>(0, 0, 0))
        let diagonal = DragPlaneMath.intersect(rayOrigin: [0, 2, 0], rayDirection: [1, -1, 0], planePoint: [0, 0, 0], planeNormal: [0, 1, 0])
        XCTAssertEqual(diagonal, SIMD3<Float>(2, 0, 0))
        XCTAssertNil(DragPlaneMath.intersect(rayOrigin: [0, 1, 0], rayDirection: [1, 0, 0], planePoint: [0, 0, 0], planeNormal: [0, 1, 0]))
        XCTAssertNil(DragPlaneMath.intersect(rayOrigin: [0, 1, 0], rayDirection: [0, 1, 0], planePoint: [0, 0, 0], planeNormal: [0, 1, 0]))
    }

    func testTargets() {
        let targets = [DragPlaneMath.Target(id: "a", center: [-1, 0, 0], radius: 0.5), DragPlaneMath.Target(id: "b", center: [1, 0, 0], radius: 0.5)]
        XCTAssertEqual(DragPlaneMath.target(containing: [0.8, 3, 0.1], among: targets)?.id, "b")
        XCTAssertNil(DragPlaneMath.target(containing: [0, 0, 0], among: targets))
        XCTAssertEqual(DragPlaneMath.xzDistance([0, 5, 0], [3, 0, 4]), 5, accuracy: 1e-6)
        let clamped = DragPlaneMath.clamped([5, 1, -5], minX: -1, maxX: 1, minZ: -2, maxZ: 2)
        XCTAssertEqual(clamped, SIMD3<Float>(1, 1, -2))
    }
}
