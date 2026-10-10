import Foundation
import RealityKit
import AICatCore
import simd

/// Third-person camera that frames AI CAT with proportions that follow its morphology and the posture.
@MainActor
final class CameraRig {
    let entity = Entity()
    private var currentPosition = SIMD3<Float>(0, 1.2, 2.6)
    private var currentTarget = SIMD3<Float>(0, 0.2, 0)
    /// 1 = default; smaller values pull the camera closer (pocket), larger values push it back.
    var distanceFactor: Float = 1
    /// Vertical bias of the viewpoint: 0.55 = default, higher = more top-down.
    var elevationFactor: Float = 0.55
    /// Horizontal offset of the subject in the frame (metres), so the cat can sit beside a board.
    var lateralOffset: Float = 0
    var subjectHeight: Float = 0.3

    init() {
        entity.name = "camera"
        entity.components.set(PerspectiveCameraComponent(near: 0.05, far: 80, fieldOfViewInDegrees: 52))
        entity.look(at: currentTarget, from: currentPosition, relativeTo: nil)
    }

    /// Smoothly follow `target` (the cat's chest in world space). Call every frame.
    func update(target: SIMD3<Float>, deltaTime: Float) {
        // Close enough that the kitten reads as the hero, far enough that a board ±1 m wide fits a portrait view.
        let distance = (1.0 + 2.6 * subjectHeight) * distanceFactor
        let height = distance * elevationFactor + subjectHeight * 0.5
        let azimuth: Float = 0.28
        let desiredPosition = SIMD3<Float>(target.x + sin(azimuth) * distance + lateralOffset, height, target.z + cos(azimuth) * distance)
        let desiredTarget = SIMD3<Float>(target.x + lateralOffset, target.y + subjectHeight * 0.25, target.z)
        let k = 1 - exp(-deltaTime * 3.5)
        currentPosition += (desiredPosition - currentPosition) * k
        currentTarget += (desiredTarget - currentTarget) * k
        entity.look(at: currentTarget, from: currentPosition, relativeTo: nil)
    }

    var position: SIMD3<Float> { currentPosition }

    func applyPosture(_ posture: StagePosture) {
        switch posture {
        case .pocket:
            distanceFactor = 1.05
            elevationFactor = 0.5
            lateralOffset = 0
        case .world:
            distanceFactor = 1.0
            elevationFactor = 0.45
            lateralOffset = 0
        case .lab:
            distanceFactor = 1.1
            elevationFactor = 0.42
            lateralOffset = 0
        case .book:
            distanceFactor = 1.0
            elevationFactor = 0.45
            lateralOffset = 0
        }
    }
}
