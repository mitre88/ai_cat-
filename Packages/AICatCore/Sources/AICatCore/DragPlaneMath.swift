import Foundation

/// Pure geometry for dragging props on the ground plane and deciding which basket a drop belongs to.
/// (The physics engine is cosmetic: scoring uses these functions.)
public enum DragPlaneMath {
    /// Intersection of a ray with a plane. Returns nil when the ray is parallel or points away.
    public static func intersect(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>,
                                 planePoint: SIMD3<Float>, planeNormal: SIMD3<Float>) -> SIMD3<Float>? {
        let denom = dot(planeNormal, rayDirection)
        if abs(denom) < 1e-6 { return nil }
        let t = dot(planeNormal, planePoint - rayOrigin) / denom
        if t < 0 { return nil }
        return rayOrigin + rayDirection * t
    }

    /// Horizontal (XZ) distance between two points.
    public static func xzDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return (dx * dx + dz * dz).squareRoot()
    }

    public struct Target: Equatable, Sendable {
        public var id: String
        public var center: SIMD3<Float>
        public var radius: Float

        public init(id: String, center: SIMD3<Float>, radius: Float) {
            self.id = id
            self.center = center
            self.radius = radius
        }
    }

    /// The closest target whose radius contains the point (XZ), or nil.
    public static func target(containing point: SIMD3<Float>, among targets: [Target]) -> Target? {
        var best: Target?
        var bestDistance = Float.greatestFiniteMagnitude
        for t in targets {
            let d = xzDistance(point, t.center)
            if d <= t.radius, d < bestDistance {
                best = t
                bestDistance = d
            }
        }
        return best
    }

    /// Clamp a point to a rectangular play area on the ground (keeps dragged props reachable).
    public static func clamped(_ p: SIMD3<Float>, minX: Float, maxX: Float, minZ: Float, maxZ: Float) -> SIMD3<Float> {
        SIMD3<Float>(min(max(p.x, minX), maxX), p.y, min(max(p.z, minZ), maxZ))
    }

    @inlinable
    public static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        a.x * b.x + a.y * b.y + a.z * b.z
    }
}
