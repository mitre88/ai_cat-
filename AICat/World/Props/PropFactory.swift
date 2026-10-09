import RealityKit
import SwiftUI
import AICatCore

/// Low-poly props built from primitives. Replace any of them with USDZ later (see Docs/ART_PIPELINE.md).
enum PropFactory {
    static func tree(height: Float, palette: WorldPalette) -> Entity {
        let tree = Entity()
        let trunk = ModelEntity(mesh: .generateCylinder(height: height * 0.35, radius: height * 0.05), materials: [Materials.matte(Color(red: 0.45, green: 0.3, blue: 0.18))])
        trunk.position = [0, height * 0.175, 0]
        let canopy = ModelEntity(mesh: .generateCone(height: height * 0.7, radius: height * 0.28), materials: [Materials.matte(palette.accent)])
        canopy.position = [0, height * 0.35 + height * 0.35, 0]
        let canopy2 = ModelEntity(mesh: .generateCone(height: height * 0.5, radius: height * 0.22), materials: [Materials.matte(palette.accent.opacity(0.9))])
        canopy2.position = [0, height * 0.35 + height * 0.62, 0]
        for model in [trunk, canopy, canopy2] {
            model.components.set(GroundingShadowComponent(castsShadow: true))
            tree.addChild(model)
        }
        return tree
    }

    static func flower(color: Color, height: Float) -> Entity {
        let flower = Entity()
        let stem = ModelEntity(mesh: .generateCylinder(height: height, radius: height * 0.06), materials: [Materials.matte(Color(red: 0.3, green: 0.6, blue: 0.3))])
        stem.position = [0, height / 2, 0]
        let bloom = ModelEntity(mesh: .generateSphere(radius: height * 0.28), materials: [Materials.glossy(color)])
        bloom.position = [0, height, 0]
        bloom.components.set(GroundingShadowComponent(castsShadow: true))
        flower.addChild(stem)
        flower.addChild(bloom)
        return flower
    }

    static func hedge(width: Float, height: Float, color: Color) -> ModelEntity {
        let hedge = ModelEntity(mesh: .generateBox(size: [width, height, height * 0.8], cornerRadius: height * 0.3), materials: [Materials.matte(color)])
        hedge.position = [0, height / 2, 0]
        hedge.components.set(GroundingShadowComponent(castsShadow: true))
        return hedge
    }

    static func bookshelf(width: Float, height: Float, palette: WorldPalette) -> Entity {
        let shelf = Entity()
        let frame = ModelEntity(mesh: .generateBox(size: [width, height, 0.25], cornerRadius: 0.01), materials: [Materials.matte(palette.ground)])
        frame.position = [0, height / 2, 0]
        frame.components.set(GroundingShadowComponent(castsShadow: true))
        shelf.addChild(frame)
        let rows = 3
        let perRow = 6
        let colors = [palette.primary, palette.secondary, palette.accent, Color.red, Color.blue, Color.orange]
        for row in 0..<rows {
            for i in 0..<perRow {
                let bookWidth = width / Float(perRow) * 0.8
                let bookHeight = height / Float(rows) * 0.7
                let book = ModelEntity(mesh: .generateBox(size: [bookWidth, bookHeight, 0.16], cornerRadius: 0.004), materials: [Materials.matte(colors[(row * perRow + i) % colors.count])])
                let x = -width / 2 + bookWidth * 0.65 + Float(i) * (width / Float(perRow))
                let y = Float(row) * (height / Float(rows)) + bookHeight / 2 + 0.03
                book.position = [x, y, 0.08]
                shelf.addChild(book)
            }
        }
        return shelf
    }

    /// Open basket: a bucket body with a contrasting rim. Collider is a static cylinder so fruit lands inside.
    static func basket(color: Color, radius: Float, height: Float) -> ModelEntity {
        let basket = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [Materials.matte(color)])
        basket.position = [0, height / 2, 0]
        let rim = ModelEntity(mesh: .generateCylinder(height: height * 0.12, radius: radius * 1.08), materials: [Materials.glossy(color.opacity(0.95))])
        rim.position = [0, height * 0.5, 0]
        basket.addChild(rim)
        basket.components.set(GroundingShadowComponent(castsShadow: true))
        basket.collision = CollisionComponent(shapes: [.generateBox(size: [radius * 2, height, radius * 2])])
        basket.physicsBody = PhysicsBodyComponent(shapes: [.generateBox(size: [radius * 2, height, radius * 2])], mass: 0, material: PhysicsMaterialResource.generate(staticFriction: 0.8, dynamicFriction: 0.7, restitution: 0.05), mode: .static)
        return basket
    }

    static func pedestal(color: Color, radius: Float) -> ModelEntity {
        let pedestal = ModelEntity(mesh: .generateCylinder(height: 0.06, radius: radius), materials: [Materials.matte(color)])
        pedestal.position = [0, 0.03, 0]
        pedestal.components.set(GroundingShadowComponent(castsShadow: true))
        return pedestal
    }
}
