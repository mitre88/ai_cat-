import XCTest
@testable import AICatCore

final class CatAnimatorTests: XCTestCase {
    private func run(_ animator: CatAnimator, seconds: Float, from position: SIMD3<Float> = .zero, yaw: Float = 0,
                     camera: SIMD3<Float> = [0, 1, 2], body: (CatPose) -> Void = { _ in }) -> CatPose {
        var p = position
        var y = yaw
        var last = animator.step(deltaTime: 0, rootPosition: p, rootYaw: y, cameraPosition: camera)
        let dt: Float = 1.0 / 60.0
        var t: Float = 0
        while t < seconds {
            last = animator.step(deltaTime: dt, rootPosition: p, rootYaw: y, cameraPosition: camera)
            p = last.rootPosition
            y = last.rootYaw
            body(last)
            t += dt
        }
        return last
    }

    func testWalkingArrivesAndFacesTheTarget() {
        let animator = CatAnimator()
        animator.configure(morphology: .kitten)
        var arrived = false
        animator.onArrive = { arrived = true }
        animator.walkTarget = [1, 0, 0]
        let pose = run(animator, seconds: 20)
        XCTAssertTrue(arrived)
        XCTAssertFalse(animator.isWalking)
        XCTAssertEqual(pose.rootPosition.x, 1, accuracy: 0.05)
        XCTAssertEqual(pose.rootPosition.z, 0, accuracy: 0.05)
        XCTAssertEqual(pose.rootYaw, .pi / 2, accuracy: 0.05)
    }

    func testAdultWalksFasterThanKitten() {
        func distanceAfterTwoSeconds(_ m: CatMorphology) -> Float {
            let a = CatAnimator()
            a.configure(morphology: m)
            a.walkTarget = [0, 0, 5]
            return run(a, seconds: 2).rootPosition.z
        }
        XCTAssertGreaterThan(distanceAfterTwoSeconds(CatMorphology.adult), distanceAfterTwoSeconds(CatMorphology.kitten) * 1.5)
    }

    func testBlinksAndBreathes() {
        let animator = CatAnimator(seed: 3)
        var blinked = false
        var minScale: Float = 10, maxScale: Float = 0
        _ = run(animator, seconds: 8) { pose in
            if pose.eyeOpenLeft <= 0.12 { blinked = true }
            minScale = min(minScale, pose.bodyScale.x)
            maxScale = max(maxScale, pose.bodyScale.x)
        }
        XCTAssertTrue(blinked, "should blink within 8 seconds")
        XCTAssertGreaterThan(maxScale - minScale, 0.03, "breathing should move the body scale")
    }

    func testGesturesEndAndJumpLeavesTheGround() {
        let animator = CatAnimator()
        animator.configure(morphology: .kitten)
        animator.play(.jump)
        var maxY: Float = 0
        _ = run(animator, seconds: 0.4) { maxY = max(maxY, $0.rootPosition.y) }
        XCTAssertEqual(animator.currentGesture, .jump)
        XCTAssertGreaterThan(maxY, 0.05)
        _ = run(animator, seconds: 0.5)
        XCTAssertEqual(animator.currentGesture, .none)
        for gesture in CatGesture.allCases where gesture != .none {
            XCTAssertGreaterThan(CatAnimator.duration(of: gesture), 0)
        }
    }

    func testEmotionTablesAndGaze() {
        let animator = CatAnimator()
        animator.emotion = .sleepy
        let sleepy = animator.baseEyeOpenness().left
        animator.emotion = .excited
        let excited = animator.baseEyeOpenness().left
        XCTAssertLessThan(sleepy, excited)
        XCTAssertGreaterThan(animator.tailParameters().amplitude, 0.5)
        // Looking at a point to the right turns the head right (positive yaw) and stays within limits.
        let a = CatAnimator()
        a.configure(morphology: .kitten)
        a.gazeTarget = [3, 0.1, 0.5]
        let pose = run(a, seconds: 2)
        XCTAssertGreaterThan(pose.headYaw, 0.3)
        XCTAssertLessThanOrEqual(pose.headYaw, 0.65 + 1e-4)
    }

    func testAngleHelpers() {
        let a = CatAnimator.lerpAngle(3.0, -3.0, 1)
        XCTAssertEqual(sin(a), sin(-3.0), accuracy: 1e-5)
        XCTAssertEqual(cos(a), cos(-3.0), accuracy: 1e-5)
        XCTAssertEqual(CatAnimator.lerpAngle(0, 1, 0.5), 0.5, accuracy: 1e-6)
        let v = CatAnimator.rotateY([0, 0, 1], by: .pi / 2)
        XCTAssertEqual(v.x, 1, accuracy: 1e-6)
        XCTAssertEqual(v.z, 0, accuracy: 1e-6)
    }
}
