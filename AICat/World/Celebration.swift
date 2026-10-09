import RealityKit
import Foundation

/// Particle burst above AI CAT when a challenge ends (skipped when effects are reduced).
@MainActor
enum Celebration {
    static func burst(in world: WorldModel) {
        let emitter = Entity()
        emitter.name = "celebration"
        emitter.components.set(ParticleEmitterComponent.Presets.magic)
        emitter.position = world.cat.headPosition + SIMD3<Float>(0, 0.15, 0)
        world.root.addChild(emitter)
        Task { [weak emitter] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            emitter?.removeFromParent()
        }
    }
}
