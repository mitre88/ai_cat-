@_exported import Foundation
@_exported import simd
@_exported import UIKit
import SwiftUI

// MARK: Components

public protocol Component {}

public struct ComponentSet {
    public init() {}
    public mutating func set<T: Component>(_ component: T) {}
    public mutating func remove<T: Component>(_ type: T.Type) {}
}

public struct Transform: Equatable {
    public var scale: SIMD3<Float>
    public var rotation: simd_quatf
    public var translation: SIMD3<Float>
    public init(scale: SIMD3<Float>, rotation: simd_quatf, translation: SIMD3<Float>) {
        self.scale = scale; self.rotation = rotation; self.translation = translation
    }
    public static let identity = Transform(scale: .one, rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), translation: .zero)
}

public struct BoundingBox {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>
    public init(min: SIMD3<Float>, max: SIMD3<Float>) { self.min = min; self.max = max }
    public var center: SIMD3<Float> { (min + max) / 2 }
    public var extents: SIMD3<Float> { max - min }
}

public struct AnimationTimingFunction { public static let easeInOut = AnimationTimingFunction(); public static let easeOut = AnimationTimingFunction(); public static let easeIn = AnimationTimingFunction(); public static let linear = AnimationTimingFunction() }

public class AnimationResource {
    public func `repeat`(count: Int = 0, autoreverses: Bool = false) -> AnimationResource { self }
}

// MARK: Entities

@MainActor
open class Entity {
    public var name: String = ""
    public var position: SIMD3<Float> = .zero
    public var orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    public var scale: SIMD3<Float> = .one
    public var transform: Transform = .identity
    public private(set) var parent: Entity?
    public var children: [Entity] = []
    public var components = ComponentSet()
    public var isEnabled: Bool = true
    public var availableAnimations: [AnimationResource] = []

    public init() {}
    public convenience init(named: String, in bundle: Bundle? = nil) async throws { self.init() }

    public func addChild(_ child: Entity) { children.append(child); child.parent = self }
    public func removeFromParent() { parent = nil }
    public func convert(position: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> { position }
    public func convert(position: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> { position }
    public func look(at target: SIMD3<Float>, from position: SIMD3<Float>, upVector: SIMD3<Float> = [0, 1, 0], relativeTo referenceEntity: Entity?) {}
    public func move(to transform: Transform, relativeTo referenceEntity: Entity?, duration: TimeInterval, timingFunction: AnimationTimingFunction = .easeInOut) {}
    public func visualBounds(relativeTo referenceEntity: Entity?) -> BoundingBox { BoundingBox(min: .zero, max: .one) }
    public func playAnimation(_ animation: AnimationResource, transitionDuration: TimeInterval = 0, startsPaused: Bool = false) {}
}

public protocol Material {}

public struct ModelComponent: Component {
    public var mesh: MeshResource
    public var materials: [any Material]
    public init(mesh: MeshResource, materials: [any Material]) { self.mesh = mesh; self.materials = materials }
}

@MainActor
open class ModelEntity: Entity {
    public var model: ModelComponent?
    public var collision: CollisionComponent?
    public var physicsBody: PhysicsBodyComponent?
    public override init() { super.init() }
    public init(mesh: MeshResource, materials: [any Material] = []) { super.init(); model = ModelComponent(mesh: mesh, materials: materials) }
}

// MARK: Resources

public enum CTTextAlignment { case left, center, right }
public enum CTLineBreakMode { case byWordWrapping, byCharWrapping, byClipping }

@MainActor
public enum MeshBuffers {
    public struct Positions { public init(_ values: [SIMD3<Float>]) {} }
    public struct Normals { public init(_ values: [SIMD3<Float>]) {} }
    public struct TextureCoordinates { public init(_ values: [SIMD2<Float>]) {} }
}

public struct MeshDescriptor {
    public enum Primitives { case triangles([UInt32]) }
    public var name: String
    public var positions = MeshBuffers.Positions([])
    public var normals: MeshBuffers.Normals?
    public var textureCoordinates: MeshBuffers.TextureCoordinates?
    public var primitives: Primitives?
    public init(name: String) { self.name = name }
}

public struct DynamicLightShadowComponent: Component {
    public var castsShadow: Bool
    public init(castsShadow: Bool) { self.castsShadow = castsShadow }
}

public class MeshResource {
    public typealias Font = UIFont
    public init() {}
    public convenience init(shape: ShapeResource) { self.init() }
    public static func generate(from descriptors: [MeshDescriptor]) throws -> MeshResource { MeshResource() }
    public var bounds: BoundingBox { BoundingBox(min: .zero, max: .one) }
    public static func generateBox(size: Float, cornerRadius: Float = 0) -> MeshResource { MeshResource() }
    public static func generateBox(size: SIMD3<Float>, cornerRadius: Float = 0) -> MeshResource { MeshResource() }
    public static func generateBox(width: Float, height: Float, depth: Float, cornerRadius: Float = 0, splitFaces: Bool = false) -> MeshResource { MeshResource() }
    public static func generateSphere(radius: Float) -> MeshResource { MeshResource() }
    public static func generateCylinder(height: Float, radius: Float) -> MeshResource { MeshResource() }
    public static func generateCone(height: Float, radius: Float) -> MeshResource { MeshResource() }
    public static func generatePlane(width: Float, depth: Float, cornerRadius: Float = 0) -> MeshResource { MeshResource() }
    public static func generatePlane(width: Float, height: Float, cornerRadius: Float = 0) -> MeshResource { MeshResource() }
    public static func generateText(_ string: String, extrusionDepth: Float = 0.25, font: Font, containerFrame: CGRect = .zero, alignment: CTTextAlignment = .left, lineBreakMode: CTLineBreakMode = .byWordWrapping) -> MeshResource { MeshResource() }
}

@MainActor
public class ShapeResource {
    public init() {}
    public static func generateBox(size: SIMD3<Float>) -> ShapeResource { ShapeResource() }
    public static func generateBox(width: Float, height: Float, depth: Float) -> ShapeResource { ShapeResource() }
    public static func generateSphere(radius: Float) -> ShapeResource { ShapeResource() }
    public static func generateCapsule(height: Float, radius: Float) -> ShapeResource { ShapeResource() }
    public static func generateConvex(from mesh: MeshResource) -> ShapeResource { ShapeResource() }
    public func offsetBy(translation: SIMD3<Float>) -> ShapeResource { self }
    public func offsetBy(rotation: simd_quatf, translation: SIMD3<Float>) -> ShapeResource { self }
}

public class EnvironmentResource {
    public init() {}
    public convenience init(equirectangular image: CGImage, withName name: String?) async throws { self.init() }
}

public class PhysicsMaterialResource {
    public static func generate(staticFriction: Float = 0.8, dynamicFriction: Float = 0.6, restitution: Float = 0.1) -> PhysicsMaterialResource { PhysicsMaterialResource() }
}

// MARK: Materials

public class TextureResource {
    public enum Semantic { case color, normal, raw, hdrColor, scalar }
    public struct CreateOptions { public init(semantic: TextureResource.Semantic?) {} }
    public init() {}
    public convenience init(image: CGImage, withName name: String?, options: CreateOptions) async throws { self.init() }
}

public enum MaterialParameters {
    public struct Texture { public init(_ resource: TextureResource) {} }
}

public enum MaterialParameterTypes {
    public struct Opacity: ExpressibleByFloatLiteral { public init(floatLiteral value: Float) {}; public init(scale: Float, texture: MaterialParameters.Texture?) {}; public static var textureSemantic: TextureResource.Semantic { .raw } }
    public enum Blending { case opaque, transparent(opacity: Opacity) }
    public struct TextureCoordinateTransform { public init(offset: SIMD2<Float>, scale: SIMD2<Float>, rotation: Float) {} }
}

public struct PhysicallyBasedMaterial: Material {
    public struct BaseColor { public var tint: UIColor; public var texture: MaterialParameters.Texture?; public init(tint: UIColor, texture: MaterialParameters.Texture? = nil) { self.tint = tint; self.texture = texture } }
    public struct Roughness: ExpressibleByFloatLiteral { public init(floatLiteral value: Float) {}; public init(scale: Float, texture: MaterialParameters.Texture? = nil) {} }
    public struct Metallic: ExpressibleByFloatLiteral { public init(floatLiteral value: Float) {}; public init(scale: Float) {} }
    public struct Normal { public init(texture: MaterialParameters.Texture?) {} }
    public struct SheenColor { public init(tint: UIColor) {} }
    public struct EmissiveColor { public init(color: UIColor) {} }
    public struct Clearcoat: ExpressibleByFloatLiteral { public init(floatLiteral value: Float) {} }
    public typealias TextureCoordinateTransform = MaterialParameterTypes.TextureCoordinateTransform
    public typealias Blending = MaterialParameterTypes.Blending
    public typealias Opacity = MaterialParameterTypes.Opacity
    public var baseColor = BaseColor(tint: .white)
    public var roughness: Roughness = 0.5
    public var metallic: Metallic = 0.0
    public var normal = Normal(texture: nil)
    public var sheen: SheenColor?
    public var emissiveColor = EmissiveColor(color: .black)
    public var emissiveIntensity: Float = 0
    public var clearcoat: Clearcoat = 0.0
    public var blending: Blending = .opaque
    public var opacityThreshold: Float?
    public var writesDepth = true
    public var readsDepth = true
    public var textureCoordinateTransform = TextureCoordinateTransform(offset: .zero, scale: [1, 1], rotation: 0)
    public init() {}
}

public struct UnlitMaterial: Material {
    public typealias BaseColor = PhysicallyBasedMaterial.BaseColor
    public typealias Blending = MaterialParameterTypes.Blending
    public typealias TextureCoordinateTransform = MaterialParameterTypes.TextureCoordinateTransform
    public var color = BaseColor(tint: .white)
    public var blending: Blending = .opaque
    public var opacityThreshold: Float?
    public var writesDepth = true
    public var readsDepth = true
    public var textureCoordinateTransform = TextureCoordinateTransform(offset: .zero, scale: [1, 1], rotation: 0)
    public init() {}
    public init(color: UIColor) {}
    public init(texture: TextureResource) {}
}

public struct SimpleMaterial: Material {
    public init(color: UIColor, roughness: Float = 0.5, isMetallic: Bool = false) {}
}

// MARK: Physics & input components

public struct CollisionFilter { public init(group: Int, mask: Int) {} }
public struct CollisionComponent: Component {
    public var shapes: [ShapeResource]
    public init(shapes: [ShapeResource]) { self.shapes = shapes }
}
public enum PhysicsBodyMode { case `static`, kinematic, dynamic }
public struct PhysicsBodyComponent: Component {
    public var mode: PhysicsBodyMode
    public var isAffectedByGravity = true
    public init(shapes: [ShapeResource], mass: Float, material: PhysicsMaterialResource?, mode: PhysicsBodyMode) { self.mode = mode }
    public init() { mode = .dynamic }
}
public struct PhysicsMotionComponent: Component { public init() {} }
public struct InputTargetComponent: Component {
    public var isEnabled = true
    public init() {}
}
public struct GroundingShadowComponent: Component {
    public var castsShadow: Bool
    public var receivesShadow: Bool
    public init(castsShadow: Bool, receivesShadow: Bool = true) { self.castsShadow = castsShadow; self.receivesShadow = receivesShadow }
}
public struct BillboardComponent: Component { public init() {} }

// MARK: Lights & camera

public struct DirectionalLightComponent: Component {
    public struct Shadow: Component {
        public enum ShadowProjectionType: Equatable {
            case automatic(maximumDistance: Float)
            case fixed(zNear: Float, zFar: Float, orthographicScale: Float)
        }
        public enum ShadowMapCullMode { case none, front, back }
        public init() {}
        public init(maximumDistance: Float, depthBias: Float) {}
        public init(shadowProjection: ShadowProjectionType, depthBias: Float, cullMode: ShadowMapCullMode?) {}
        public var shadowProjection: ShadowProjectionType = .automatic(maximumDistance: 10)
        public var depthBias: Float = 1
        public var maximumDistance: Float = 10
    }
    public init(color: UIColor = .white, intensity: Float = 2145.7, isRealWorldProxy: Bool = false) {}
}
public struct PointLightComponent: Component {
    public init(color: UIColor = .white, intensity: Float = 26963.76, attenuationRadius: Float = 10) {}
}
public struct SpotLightComponent: Component { public init() {} }
public struct PerspectiveCameraComponent: Component {
    public init(near: Float = 0.01, far: Float = .infinity, fieldOfViewInDegrees: Float = 60) {}
}
public struct ImageBasedLightComponent: Component {
    public enum Source { case single(EnvironmentResource) }
    public init(source: Source, intensityExponent: Float = 0) {}
}
public struct ImageBasedLightReceiverComponent: Component {
    public init(imageBasedLight: Entity) {}
}
public struct ParticleEmitterComponent: Component {
    public struct Presets {
        public static var magic: ParticleEmitterComponent { ParticleEmitterComponent() }
        public static var fireworks: ParticleEmitterComponent { ParticleEmitterComponent() }
        public static var sparks: ParticleEmitterComponent { ParticleEmitterComponent() }
        public static var impact: ParticleEmitterComponent { ParticleEmitterComponent() }
    }
    public var isEmitting = true
    public init() {}
    public mutating func burst() {}
}

// MARK: RealityView content & events

public protocol Event {}
public enum SceneEvents {
    public struct Update: Event { public var deltaTime: TimeInterval }
}
public class EventSubscription { public init() {} }
public struct RealityViewCamera { public static let virtual = RealityViewCamera() }
public struct RealityViewEnvironment {
    public static let `default` = RealityViewEnvironment()
    public static func skybox(_ resource: EnvironmentResource) -> RealityViewEnvironment { RealityViewEnvironment() }
}
public struct RealityViewCameraContent {
    public var camera: RealityViewCamera = .virtual
    public var environment: RealityViewEnvironment = .default
    public init() {}
    public mutating func add(_ entity: Entity) {}
    public mutating func remove(_ entity: Entity) {}
    public func subscribe<E: Event>(to event: E.Type, on source: AnyObject? = nil, _ handler: @escaping (E) -> Void) -> EventSubscription { EventSubscription() }
}

// MARK: Gesture targets

public protocol RealityCoordinateSpace {}
public struct SceneRealityCoordinateSpace: RealityCoordinateSpace { public init() {} }
extension RealityCoordinateSpace where Self == SceneRealityCoordinateSpace {
    public static var scene: SceneRealityCoordinateSpace { SceneRealityCoordinateSpace() }
}

@dynamicMemberLookup
public struct EntityTargetValue<Value> {
    public var entity: Entity
    public var gestureValue: Value
    public init(entity: Entity, gestureValue: Value) { self.entity = entity; self.gestureValue = gestureValue }
    public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T { gestureValue[keyPath: keyPath] }
    public func ray(through point: CGPoint, in space: some CoordinateSpaceProtocol, to realitySpace: some RealityCoordinateSpace) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? { nil }
    public func unproject(_ point: CGPoint, from space: some CoordinateSpaceProtocol, to realitySpace: some RealityCoordinateSpace, ontoPlane: float4x4) -> SIMD3<Float>? { nil }
}

// MARK: RealityView (iOS) & entity-targeted gestures

public struct RealityView<Content: View>: View {
    public var body: Never { fatalError() }
}
extension RealityView where Content == Never {
    public init(make: @escaping @MainActor (inout RealityViewCameraContent) async -> Void,
                update: (@MainActor (inout RealityViewCameraContent) -> Void)? = nil) {}
    public init<P: View>(make: @escaping @MainActor (inout RealityViewCameraContent) async -> Void,
                         update: (@MainActor (inout RealityViewCameraContent) -> Void)? = nil,
                         @ViewBuilder placeholder: () -> P) {}
}
public struct EntityTargetGesture<G: Gesture>: Gesture {
    public typealias Value = EntityTargetValue<G.Value>
}
extension Gesture {
    public func targetedToAnyEntity() -> EntityTargetGesture<Self> { EntityTargetGesture() }
    public func targetedToEntity(_ entity: Entity) -> EntityTargetGesture<Self> { EntityTargetGesture() }
}
