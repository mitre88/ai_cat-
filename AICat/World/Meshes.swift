import Foundation
import RealityKit
import AICatCore

/// Meshes built from vertex data computed in AICatCore (tested), for the shapes RealityKit's primitives do not
/// cover with texture coordinates.
@MainActor
enum Meshes {
    /// Capsule (axis Y, centred, `height` pole to pole) with normals and UVs, so fur and fruit peel tile on
    /// it; `MeshResource(shape:)` makes no promise about UVs. Falls back to the shape mesh if generation fails.
    static func capsule(height: Float, radius: Float) -> MeshResource {
        let capsule = CapsuleMesh.build(height: height, radius: radius)
        var descriptor = MeshDescriptor(name: "capsule")
        descriptor.positions = MeshBuffers.Positions(capsule.positions)
        descriptor.normals = MeshBuffers.Normals(capsule.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(capsule.uvs)
        descriptor.primitives = .triangles(capsule.indices)
        if let mesh = try? MeshResource.generate(from: [descriptor]) {
            return mesh
        }
        return MeshResource(shape: .generateCapsule(height: height, radius: radius))
    }
}
