import Foundation

/// A capsule mesh (axis Y, centred at the origin) with normals and texture coordinates, for the bodies
/// that need a texture: RealityKit's `MeshResource(shape:)` makes no promise about UVs. `height` is the
/// total length pole to pole (like `ShapeResource.generateCapsule`); u runs around the axis, v along the
/// profile from the bottom pole (0) to the top pole (1), proportional to arc length so the texture is not
/// stretched on the caps. Triangles are counter-clockwise seen from outside (RealityKit's front face).
public struct CapsuleMesh: Sendable {
    public let positions: [SIMD3<Float>]
    public let normals: [SIMD3<Float>]
    public let uvs: [SIMD2<Float>]
    public let indices: [UInt32]

    public static func build(height: Float, radius: Float, segments: Int = 24, rings: Int = 6) -> CapsuleMesh {
        let radius = max(radius, 0.0001)
        let cylinder = max(0, height - 2 * radius)
        let segments = max(3, segments)
        let rings = max(1, rings)
        let profileLength = Float.pi * radius + cylinder
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        // profile: bottom hemisphere (φ from −π/2 to 0), then top hemisphere (0 to π/2); the two equator rings
        // are the ends of the cylinder
        var profile: [(y: Float, r: Float, ny: Float, nr: Float, s: Float)] = []
        for i in 0...rings {
            let phi = -Float.pi / 2 + Float.pi / 2 * Float(i) / Float(rings)
            let pole = i == 0   // exact pole: cos(−π/2) is not exactly 0 in Float
            profile.append((y: pole ? -cylinder / 2 - radius : -cylinder / 2 + radius * sin(phi), r: pole ? 0 : radius * cos(phi),
                            ny: pole ? -1 : sin(phi), nr: pole ? 0 : cos(phi), s: radius * (phi + Float.pi / 2)))
        }
        for i in 0...rings {
            let phi = Float.pi / 2 * Float(i) / Float(rings)
            let pole = i == rings
            profile.append((y: pole ? cylinder / 2 + radius : cylinder / 2 + radius * sin(phi), r: pole ? 0 : radius * cos(phi),
                            ny: pole ? 1 : sin(phi), nr: pole ? 0 : cos(phi), s: Float.pi / 2 * radius + cylinder + radius * phi))
        }

        for ring in profile {
            for j in 0...segments {
                let theta = 2 * Float.pi * Float(j) / Float(segments)
                let c = cos(theta)
                let s = sin(theta)
                positions.append([ring.r * c, ring.y, ring.r * s])
                let n = SIMD3<Float>(ring.nr * c, ring.ny, ring.nr * s)
                normals.append(n / max((n * n).sum().squareRoot(), 0.0001))
                uvs.append([Float(j) / Float(segments), ring.s / profileLength])
            }
        }

        var indices: [UInt32] = []
        let stride = segments + 1
        for ringIndex in 0..<(profile.count - 1) {
            if ringIndex == rings && cylinder == 0 { continue }   // sphere: the equator rings coincide
            let a = ringIndex * stride
            let b = a + stride
            for j in 0..<segments {
                let a0 = UInt32(a + j), a1 = UInt32(a + j + 1)
                let b0 = UInt32(b + j), b1 = UInt32(b + j + 1)
                if profile[ringIndex].r > 0 {           // skip the degenerate triangle at a pole ring
                    indices += [a0, b0, a1]
                }
                if profile[ringIndex + 1].r > 0 {
                    indices += [a1, b0, b1]
                }
            }
        }
        return CapsuleMesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }
}
