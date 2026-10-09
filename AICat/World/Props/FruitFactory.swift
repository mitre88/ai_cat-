import RealityKit
import SwiftUI
import UIKit
import AICatCore

/// Fruits and numbered baskets of the Pattern Garden.
enum FruitFactory {
    static func color(for fruitColor: FruitColor) -> Color {
        switch fruitColor {
        case .red: return Color(red: 0.90, green: 0.20, blue: 0.22)
        case .yellow: return Color(red: 0.98, green: 0.82, blue: 0.20)
        case .green: return Color(red: 0.35, green: 0.72, blue: 0.30)
        case .purple: return Color(red: 0.55, green: 0.30, blue: 0.75)
        }
    }

    /// Dynamic, draggable fruit. Round = sphere, long = capsule lying on its side.
    static func fruit(_ fruit: Fruit) -> ModelEntity {
        let r: Float = fruit.size == .big ? 0.095 : 0.062
        let mesh: MeshResource
        let shape: ShapeResource
        switch fruit.shape {
        case .round:
            mesh = .generateSphere(radius: r)
            shape = .generateSphere(radius: r)
        case .long:
            mesh = MeshResource(shape: .generateCapsule(height: r * 2.8, radius: r * 0.72))
            shape = .generateCapsule(height: r * 2.8, radius: r * 0.72)
        }
        let entity = ModelEntity(mesh: mesh, materials: [Materials.glossy(color(for: fruit.color))])
        entity.collision = CollisionComponent(shapes: [shape])
        entity.physicsBody = PhysicsBodyComponent(
            shapes: [shape],
            mass: 0.2,
            material: PhysicsMaterialResource.generate(staticFriction: 0.7, dynamicFriction: 0.6, restitution: 0.25),
            mode: .dynamic
        )
        entity.components.set(InputTargetComponent())
        entity.components.set(GroundingShadowComponent(castsShadow: true))
        if fruit.shape == .long {
            entity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        }
        let leaf = ModelEntity(mesh: .generateCone(height: r * 0.5, radius: r * 0.25), materials: [Materials.matte(Color(red: 0.3, green: 0.6, blue: 0.3))])
        leaf.position = fruit.shape == .round ? [0, r * 1.05, 0] : [0, r * 1.6, 0]
        entity.addChild(leaf)
        return entity
    }

    /// Basket on the ground with a floating number that always faces the camera.
    static func basket(index: Int, color: Color, radius: Float, height: Float) -> Entity {
        let container = Entity()
        let basket = PropFactory.basket(color: color, radius: radius, height: height)
        container.addChild(basket)
        let text = MeshResource.generateText(
            "\(index)",
            extrusionDepth: 0.01,
            font: UIFont.systemFont(ofSize: 0.16, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let label = ModelEntity(mesh: text, materials: [UnlitMaterial(color: .white)])
        let bounds = text.bounds
        label.position = [-bounds.center.x, height + 0.10, 0]
        label.components.set(BillboardComponent())
        container.addChild(label)
        return container
    }
}
