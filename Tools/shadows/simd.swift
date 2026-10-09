import Foundation

public struct simd_quatf: Equatable {
    public var vector: SIMD4<Float>
    public init(vector: SIMD4<Float>) { self.vector = vector }
    public init(ix: Float, iy: Float, iz: Float, r: Float) { vector = SIMD4<Float>(ix, iy, iz, r) }
    public init(angle: Float, axis: SIMD3<Float>) {
        let h = angle / 2
        let s = sin(h)
        vector = SIMD4<Float>(axis.x * s, axis.y * s, axis.z * s, cos(h))
    }
    public var axis: SIMD3<Float> { SIMD3<Float>(vector.x, vector.y, vector.z) }
    public var real: Float { vector.w }
    public func act(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let q = axis
        let t = 2 * simd_cross(q, v)
        return v + real * t + simd_cross(q, t)
    }
    public static func * (lhs: simd_quatf, rhs: simd_quatf) -> simd_quatf {
        let a = lhs.axis, b = rhs.axis
        let r = lhs.real * rhs.real - simd_dot(a, b)
        let i = lhs.real * b + rhs.real * a + simd_cross(a, b)
        return simd_quatf(ix: i.x, iy: i.y, iz: i.z, r: r)
    }
}

public func simd_length(_ v: SIMD3<Float>) -> Float { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }
public func simd_normalize(_ v: SIMD3<Float>) -> SIMD3<Float> { v / max(simd_length(v), 1e-9) }
public func simd_dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { a.x * b.x + a.y * b.y + a.z * b.z }
public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
public func length(_ v: SIMD3<Float>) -> Float { simd_length(v) }
public func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> { simd_normalize(v) }
public typealias float4x4 = [[Float]]
