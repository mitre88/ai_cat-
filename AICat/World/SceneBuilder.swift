import RealityKit
import SwiftUI
import AICatCore

/// Builds the static set of a world: ground with physics and the decoration of each theme.
@MainActor
enum SceneBuilder {
    static let groundSize: Float = 14

    static func build(theme: WorldTheme, into root: Entity) {
        let palette = Theme.palette(for: theme)
        let ground = ModelEntity(mesh: .generatePlane(width: groundSize, depth: groundSize, cornerRadius: 0), materials: [Materials.ground(palette.ground)])
        ground.name = "ground"
        let slab = ShapeResource.generateBox(size: [groundSize, 0.1, groundSize]).offsetBy(translation: [0, -0.05, 0])
        ground.collision = CollisionComponent(shapes: [slab])
        ground.physicsBody = PhysicsBodyComponent(shapes: [slab], mass: 0, material: PhysicsMaterialResource.generate(staticFriction: 0.9, dynamicFriction: 0.7, restitution: 0.1), mode: .static)
        root.addChild(ground)

        var rng = SeededGenerator(seed: UInt64(WorldTheme.allCases.firstIndex(of: theme) ?? 0) &+ 7)
        switch theme {
        case .garden:
            for (x, z, h) in [(-2.4, -2.2, 1.4), (2.6, -2.6, 1.7), (-3.2, 0.4, 1.1), (3.4, 0.2, 1.3)] {
                let tree = PropFactory.tree(height: Float(h), palette: palette)
                tree.position = [Float(x), 0, Float(z)]
                root.addChild(tree)
            }
            let hedge = PropFactory.hedge(width: 7, height: 0.45, color: palette.accent.opacity(0.9))
            hedge.position = [0, 0, -3.4]
            root.addChild(hedge)
            let colors = [palette.primary, palette.secondary, Color.pink, Color.purple]
            for i in 0..<8 {
                let flower = PropFactory.flower(color: colors[i % colors.count], height: Float(0.12 + rng.nextDouble(in: 0..<0.08)))
                flower.position = [Float(rng.nextDouble(in: -2.8..<2.8)), 0, Float(rng.nextDouble(in: -2.9 ..< -1.3))]
                root.addChild(flower)
            }
        case .library:
            for x in [-1.9, 1.9] {
                let shelf = PropFactory.bookshelf(width: 1.6, height: 1.5, palette: palette)
                shelf.position = [Float(x), 0, -2.2]
                root.addChild(shelf)
            }
            let rug = ModelEntity(mesh: .generatePlane(width: 3.2, depth: 2.2, cornerRadius: 0.3), materials: [Materials.matte(palette.secondary.opacity(0.9))])
            rug.position = [0, 0.004, -0.4]
            root.addChild(rug)
        default:
            for (x, z) in [(-2.5, -2.4), (2.5, -2.4)] {
                let tree = PropFactory.tree(height: 1.3, palette: palette)
                tree.position = [Float(x), 0, Float(z)]
                root.addChild(tree)
            }
            let block = PropFactory.hedge(width: 2.5, height: 0.5, color: palette.primary.opacity(0.8))
            block.position = [0, 0, -2.8]
            root.addChild(block)
        }
    }
}
