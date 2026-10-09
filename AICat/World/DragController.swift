import RealityKit
import SwiftUI
import AICatCore

/// Receives drag gestures that start on an entity of the stage.
@MainActor
protocol WorldInteraction: AnyObject {
    func dragChanged(_ value: EntityTargetValue<DragGesture.Value>)
    func dragEnded(_ value: EntityTargetValue<DragGesture.Value>)
}

/// Shared drag math: the touch ray meets a horizontal plane at `height`, scoring stays in AICatCore.
@MainActor
enum DragMath {
    static func groundPoint(for value: EntityTargetValue<DragGesture.Value>, height: Float) -> SIMD3<Float>? {
        guard let ray = value.ray(through: value.location, in: .local, to: .scene) else { return nil }
        return DragPlaneMath.intersect(rayOrigin: ray.origin, rayDirection: ray.direction,
                                       planePoint: [0, height, 0], planeNormal: [0, 1, 0])
    }

    /// Walks up from the hit entity to find a named prop.
    static func propID(for entity: Entity, among ids: Set<String>) -> String? {
        var current: Entity? = entity
        while let e = current {
            if ids.contains(e.name) { return e.name }
            current = e.parent
        }
        return nil
    }
}
