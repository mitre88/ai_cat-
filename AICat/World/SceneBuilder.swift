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
        case .workshop:
            for x in [-2.0, 2.0] {
                let bench = box([1.4, 0.5, 0.6], Materials.matte(palette.secondary))
                bench.position = [Float(x), 0.25, -2.3]
                root.addChild(bench)
            }
            let pegboard = box([3.2, 1.2, 0.08], Materials.matte(palette.primary.opacity(0.9)))
            pegboard.position = [0, 0.9, -3.3]
            root.addChild(pegboard)
            for (i, x) in [-0.9, 0.0, 0.9].enumerated() {
                let gear = cylinder(height: 0.06, radius: 0.18 + Float(i % 2) * 0.06, Materials.glossy(palette.accent))
                gear.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                gear.position = [Float(x), 0.9 + Float(i % 2) * 0.25, -3.24]
                root.addChild(gear)
            }
        case .trail:
            let path = ModelEntity(mesh: .generatePlane(width: 1.3, depth: 6, cornerRadius: 0.4), materials: [Materials.matte(palette.accent.opacity(0.8))])
            path.position = [0.6, 0.004, -2.2]
            root.addChild(path)
            for (x, z, h) in [(-2.6, -2.0, 1.5), (2.8, -3.0, 1.8), (-3.0, -3.2, 1.2), (3.2, -1.4, 1.1)] {
                let tree = PropFactory.tree(height: Float(h), palette: palette)
                tree.position = [Float(x), 0, Float(z)]
                root.addChild(tree)
            }
            for _ in 0..<5 {
                let rock = sphere(radius: Float(0.1 + rng.nextDouble(in: 0..<0.12)), Materials.matte(Color(red: 0.55, green: 0.55, blue: 0.5)))
                rock.position = [Float(rng.nextDouble(in: -3.2..<3.2)), 0.08, Float(rng.nextDouble(in: -3.3 ..< -1.4))]
                root.addChild(rock)
            }
        case .maze:
            for (x, z, w) in [(-2.3, -2.0, 2.4), (2.3, -2.0, 2.4), (0.0, -3.3, 5.2)] {
                let hedge = PropFactory.hedge(width: Float(w), height: 0.65, color: palette.primary.opacity(0.9))
                hedge.position = [Float(x), 0, Float(z)]
                root.addChild(hedge)
            }
            for i in 0..<4 {
                let flower = PropFactory.flower(color: i % 2 == 0 ? palette.accent : Color.pink, height: 0.14)
                flower.position = [Float(-1.2 + Double(i) * 0.8), 0, -1.5]
                root.addChild(flower)
            }
        case .factory:
            for x in [-2.6, 2.6] {
                let chimney = cylinder(height: 1.7, radius: 0.18, Materials.matte(palette.secondary))
                chimney.position = [Float(x), 0.85, -3.0]
                root.addChild(chimney)
                let puff = sphere(radius: 0.22, Materials.matte(Color(red: 0.85, green: 0.85, blue: 0.88)))
                puff.position = [Float(x) + 0.1, 1.9, -3.0]
                root.addChild(puff)
            }
            let conveyor = box([3.2, 0.3, 0.6], Materials.matte(palette.primary.opacity(0.9)))
            conveyor.position = [0, 0.15, -2.4]
            root.addChild(conveyor)
            for x in [-1.0, 0.0, 1.0] {
                let gear = cylinder(height: 0.08, radius: 0.2, Materials.glossy(palette.accent))
                gear.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                gear.position = [Float(x), 0.55, -2.4]
                root.addChild(gear)
            }
        case .lookout:
            let tower = cylinder(height: 1.8, radius: 0.35, Materials.matte(palette.secondary))
            tower.position = [2.7, 0.9, -2.9]
            root.addChild(tower)
            let roof = ModelEntity(mesh: .generateCone(height: 0.6, radius: 0.5), materials: [Materials.matte(palette.accent)])
            roof.position = [2.7, 2.1, -2.9]
            root.addChild(roof)
            for (x, z, r) in [(-2.4, -2.2, 0.35), (-3.1, -1.6, 0.28), (-1.5, -3.0, 0.3), (1.0, -3.2, 0.26)] {
                let bush = sphere(radius: Float(r), Materials.matte(palette.primary))
                bush.position = [Float(x), Float(r) * 0.8, Float(z)]
                root.addChild(bush)
            }
        case .theater:
            for x in [-2.6, 2.6] {
                let curtain = box([0.5, 2.2, 0.12], Materials.matte(Color(red: 0.7, green: 0.15, blue: 0.2)))
                curtain.position = [Float(x), 1.1, -3.0]
                root.addChild(curtain)
            }
            let backdrop = box([6, 2.3, 0.06], Materials.matte(palette.secondary.opacity(0.9)))
            backdrop.position = [0, 1.15, -3.4]
            root.addChild(backdrop)
            let platform = box([5.4, 0.2, 2.0], Materials.matte(palette.primary))
            platform.position = [0, 0.1, -2.3]
            root.addChild(platform)
            for x in [-1.6, 1.6] {
                let pole = cylinder(height: 1.6, radius: 0.025, Materials.matte(Color.gray))
                pole.position = [Float(x), 0.8, -1.5]
                root.addChild(pole)
                let lamp = sphere(radius: 0.08, Materials.glowing(Color(red: 1, green: 0.9, blue: 0.6), intensity: 1.5))
                lamp.position = [Float(x), 1.62, -1.5]
                root.addChild(lamp)
            }
        case .plaza:
            let basin = cylinder(height: 0.25, radius: 0.75, Materials.matte(palette.secondary))
            basin.position = [0, 0.125, -2.6]
            root.addChild(basin)
            let water = cylinder(height: 0.02, radius: 0.68, Materials.glossy(Color(red: 0.35, green: 0.65, blue: 0.95)))
            water.position = [0, 0.26, -2.6]
            root.addChild(water)
            let spout = cylinder(height: 0.6, radius: 0.12, Materials.matte(palette.accent))
            spout.position = [0, 0.55, -2.6]
            root.addChild(spout)
            for x in [-2.4, 2.4] {
                let bench = box([1.1, 0.12, 0.4], Materials.matte(palette.primary))
                bench.position = [Float(x), 0.42, -2.0]
                root.addChild(bench)
                let post = cylinder(height: 1.4, radius: 0.03, Materials.matte(Color(red: 0.3, green: 0.3, blue: 0.35)))
                post.position = [Float(x), 0.7, -3.1]
                root.addChild(post)
                let globe = sphere(radius: 0.1, Materials.glowing(Color(red: 1, green: 0.95, blue: 0.75), intensity: 1.4))
                globe.position = [Float(x), 1.45, -3.1]
                root.addChild(globe)
            }
        case .lab:
            for x in [-1.9, 1.9] {
                let table = box([1.5, 0.7, 0.6], Materials.matte(palette.secondary))
                table.position = [Float(x), 0.35, -2.3]
                root.addChild(table)
                for (i, dx) in [-0.4, 0.0, 0.4].enumerated() {
                    let colors = [palette.accent, palette.primary, Color(red: 0.4, green: 0.8, blue: 1.0)]
                    let flask = cylinder(height: 0.22, radius: 0.06, Materials.glossy(colors[i % colors.count]))
                    flask.position = [Float(x + dx), 0.81, -2.3]
                    root.addChild(flask)
                }
            }
            let board = box([2.6, 1.2, 0.06], Materials.matte(Color(red: 0.15, green: 0.35, blue: 0.3)))
            board.position = [0, 1.0, -3.3]
            root.addChild(board)
        }
    }

    private static func box(_ size: SIMD3<Float>, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.02), materials: [material])
    }

    private static func cylinder(height: Float, radius: Float, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [material])
    }

    private static func sphere(radius: Float, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
    }
}
