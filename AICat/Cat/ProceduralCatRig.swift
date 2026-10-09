import RealityKit
import simd
import SwiftUI
import AICatCore

/// AI CAT built from primitives. Local convention: the nose points to +Z, the tail to −Z, Y is up,
/// and the root sits on the ground between the paws. Every dimension comes from `CatMorphology`.
@MainActor
final class ProceduralCatRig: CatRig {
    let root = Entity()
    private(set) var morphology: CatMorphology = .kitten
    private(set) var emotion: CatEmotion = .happy

    // parts
    private let body = ModelEntity()
    private let headPivot = Entity()
    private let head = ModelEntity()
    private let earL = ModelEntity()
    private let earR = ModelEntity()
    private let innerEarL = ModelEntity()
    private let innerEarR = ModelEntity()
    private let eyeL = ModelEntity()
    private let eyeR = ModelEntity()
    private let pupilL = ModelEntity()
    private let pupilR = ModelEntity()
    private let nose = ModelEntity()
    private let legs: [ModelEntity] = [ModelEntity(), ModelEntity(), ModelEntity(), ModelEntity()]   // FL, FR, BL, BR
    private let tailPivot = Entity()
    private let tailSegments: [ModelEntity] = [ModelEntity(), ModelEntity(), ModelEntity(), ModelEntity()]
    private let accessories = Entity()
    private let shadowDisc = ModelEntity()

    let animator = CatAnimator()
    private var growthScaleTween: (from: Float, elapsed: Float)?

    init() {
        root.name = "aiCat"
        root.addChild(body)
        for leg in legs { root.addChild(leg) }
        root.addChild(headPivot)
        headPivot.addChild(head)
        head.addChild(earL)
        head.addChild(earR)
        earL.addChild(innerEarL)
        earR.addChild(innerEarR)
        head.addChild(eyeL)
        head.addChild(eyeR)
        eyeL.addChild(pupilL)
        eyeR.addChild(pupilR)
        head.addChild(nose)
        root.addChild(tailPivot)
        var parent: Entity = tailPivot
        for segment in tailSegments {
            parent.addChild(segment)
            parent = segment
        }
        root.addChild(accessories)
        shadowDisc.name = "contactShadow"
        root.addChild(shadowDisc)
        for model in [body, head, earL, earR] + legs + tailSegments {
            model.components.set(GroundingShadowComponent(castsShadow: true))
        }
        apply(morphology: .kitten, animated: false)
    }

    // MARK: CatMorphology

    func apply(morphology m: CatMorphology, animated: Bool) {
        let previousHeight = Float(morphology.standingHeight)
        morphology = m
        let bodyLength = Float(m.bodyLength)
        let bodyRadius = Float(m.bodyRadius)
        let headRadius = Float(m.headRadius)
        let legLength = Float(m.legLength)
        let legRadius = Float(m.legRadius)
        let eyeRadius = Float(m.eyeRadius)
        let earHeight = Float(m.earHeight)
        let earRadius = Float(m.earRadius)
        let tailLength = Float(m.tailLength)
        let tailRadius = Float(m.tailRadius)

        body.model = ModelComponent(mesh: MeshResource(shape: .generateCapsule(height: bodyLength, radius: bodyRadius)), materials: [Materials.fur])
        body.position = [0, Float(m.bodyCenterHeight), 0]
        body.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])   // capsule axis along Z

        let legMesh = MeshResource.generateCylinder(height: legLength + bodyRadius * 0.6, radius: legRadius)
        let dx = bodyRadius * 0.58
        let dz = bodyLength * 0.30
        let legOffsets: [SIMD3<Float>] = [[-dx, 0, dz], [dx, 0, dz], [-dx, 0, -dz], [dx, 0, -dz]]
        for (leg, offset) in zip(legs, legOffsets) {
            leg.model = ModelComponent(mesh: legMesh, materials: [Materials.fur])
            leg.position = [offset.x, (legLength + bodyRadius * 0.6) / 2, offset.z]
        }

        headPivot.position = [0, Float(m.headCenterHeight), bodyLength * 0.42]
        head.model = ModelComponent(mesh: .generateSphere(radius: headRadius), materials: [Materials.fur])
        head.position = .zero

        let earMesh = MeshResource.generateCone(height: earHeight, radius: earRadius)
        let innerMesh = MeshResource.generateCone(height: earHeight * 0.6, radius: earRadius * 0.55)
        for (ear, sign) in [(earL, Float(-1)), (earR, Float(1))] {
            ear.model = ModelComponent(mesh: earMesh, materials: [Materials.fur])
            ear.position = [sign * headRadius * 0.55, headRadius * 0.78, -headRadius * 0.05]
            ear.orientation = simd_quatf(angle: sign * 0.28, axis: [0, 0, 1])
        }
        for inner in [innerEarL, innerEarR] {
            inner.model = ModelComponent(mesh: innerMesh, materials: [Materials.innerEar])
            inner.position = [0, -earHeight * 0.12, earRadius * 0.35]
        }

        let eyeMesh = MeshResource.generateSphere(radius: eyeRadius)
        let pupilMesh = MeshResource.generateSphere(radius: eyeRadius * 0.45)
        for (eye, sign) in [(eyeL, Float(-1)), (eyeR, Float(1))] {
            eye.model = ModelComponent(mesh: eyeMesh, materials: [Materials.eye])
            eye.position = [sign * headRadius * 0.40, headRadius * 0.12, headRadius * 0.80]
        }
        for pupil in [pupilL, pupilR] {
            pupil.model = ModelComponent(mesh: pupilMesh, materials: [Materials.pupil])
            pupil.position = [0, 0, eyeRadius * 0.70]
        }
        nose.model = ModelComponent(mesh: .generateSphere(radius: Float(m.noseRadius)), materials: [Materials.nose])
        nose.position = [0, -headRadius * 0.12, headRadius * 0.96]

        tailPivot.position = [0, Float(m.bodyCenterHeight) + bodyRadius * 0.35, -bodyLength * 0.48]
        let segmentLength = tailLength / Float(tailSegments.count)
        let segmentMesh = MeshResource(shape: .generateCapsule(height: segmentLength * 1.15, radius: tailRadius))
        for (index, segment) in tailSegments.enumerated() {
            segment.model = ModelComponent(mesh: segmentMesh, materials: [Materials.fur])
            // each segment hangs off the previous one, curling upwards
            segment.position = index == 0 ? [0, 0, 0] : [0, segmentLength * 0.35, -segmentLength * 0.9]
            segment.orientation = simd_quatf(angle: -0.55 + Float(index) * 0.35, axis: [1, 0, 0])
        }

        let shadowWidth = bodyLength * 1.6 + 0.12
        shadowDisc.model = ModelComponent(mesh: .generatePlane(width: shadowWidth, depth: shadowWidth * 0.75, cornerRadius: 0), materials: [Materials.blobShadow])
        shadowDisc.position = [0, 0.004, bodyLength * 0.06]

        rebuildAccessories()
        animator.configure(morphology: m)

        if animated {
            let newHeight = Float(m.standingHeight)
            growthScaleTween = (from: max(previousHeight / max(newHeight, 0.001), 0.2), elapsed: 0)
            root.scale = SIMD3<Float>(repeating: growthScaleTween?.from ?? 1)
        } else {
            growthScaleTween = nil
            root.scale = [1, 1, 1]
        }
    }

    // MARK: Accessories

    private var worn: [KnowledgeItem] = []

    func wear(_ items: [KnowledgeItem]) {
        worn = items
        rebuildAccessories()
    }

    private func rebuildAccessories() {
        for child in Array(accessories.children) {
            child.removeFromParent()
        }
        let m = morphology
        let headRadius = Float(m.headRadius)
        let bodyRadius = Float(m.bodyRadius)
        for item in worn {
            switch item {
            case .collar:
                let ring = ModelEntity(mesh: .generateCylinder(height: headRadius * 0.16, radius: headRadius * 0.62), materials: [Materials.glossy(Color(red: 0.95, green: 0.35, blue: 0.3))])
                ring.position = [0, Float(m.headCenterHeight) - headRadius * 0.95, Float(m.bodyLength) * 0.40]
                accessories.addChild(ring)
            case .bandana:
                let cloth = ModelEntity(mesh: .generateBox(size: [headRadius * 1.1, headRadius * 0.08, headRadius * 0.9], cornerRadius: 0.004), materials: [Materials.matte(Color(red: 0.3, green: 0.55, blue: 0.9))])
                cloth.position = [0, Float(m.headCenterHeight) - headRadius * 1.0, Float(m.bodyLength) * 0.33]
                accessories.addChild(cloth)
            case .glasses:
                let frame = ModelEntity(mesh: .generateBox(size: [headRadius * 1.2, headRadius * 0.28, headRadius * 0.06], cornerRadius: 0.004), materials: [Materials.glossy(Color(red: 0.2, green: 0.2, blue: 0.25))])
                frame.position = [0, Float(m.headCenterHeight) + headRadius * 0.12, Float(m.bodyLength) * 0.42 + headRadius * 0.92]
                accessories.addChild(frame)
            case .graduationCap:
                let board = ModelEntity(mesh: .generateBox(size: [headRadius * 1.5, headRadius * 0.06, headRadius * 1.5], cornerRadius: 0.003), materials: [Materials.matte(Color(red: 0.12, green: 0.12, blue: 0.2))])
                board.position = [0, Float(m.headCenterHeight) + headRadius * 1.05, Float(m.bodyLength) * 0.42]
                accessories.addChild(board)
            default:
                let charm = ModelEntity(mesh: .generateSphere(radius: bodyRadius * 0.18), materials: [Materials.glossy(Color(red: 0.98, green: 0.78, blue: 0.25))])
                charm.position = [0, Float(m.headCenterHeight) - headRadius * 1.05, Float(m.bodyLength) * 0.40 + headRadius * 0.6]
                accessories.addChild(charm)
            }
        }
    }

    // MARK: Behaviour

    func set(emotion: CatEmotion) {
        self.emotion = emotion
        animator.emotion = emotion
    }

    func play(gesture: CatGesture) {
        animator.play(gesture)
    }

    func lookAt(_ point: SIMD3<Float>?) {
        animator.gazeTarget = point
    }

    func walk(to point: SIMD3<Float>, completion: (() -> Void)?) {
        animator.onArrive = completion
        animator.walkTarget = point
    }

    func stopWalking() {
        animator.onArrive = nil
        animator.walkTarget = nil
    }

    /// Yaw (rotation about Y) of an orientation whose forward axis is +Z.
    private static func yaw(of orientation: simd_quatf) -> Float {
        let forward = orientation.act(SIMD3<Float>(0, 0, 1))
        return atan2(forward.x, forward.z)
    }

    var chestPosition: SIMD3<Float> {
        root.convert(position: [0, Float(morphology.bodyCenterHeight), 0], to: nil)
    }

    var headPosition: SIMD3<Float> {
        headPivot.convert(position: .zero, to: nil)
    }

    func update(deltaTime: Float, cameraPosition: SIMD3<Float>) {
        if var tween = growthScaleTween {
            tween.elapsed += deltaTime
            let t = min(tween.elapsed / 0.9, 1)
            let eased = 1 - pow(1 - t, 3)
            let overshoot = 1 + 0.08 * sin(t * .pi)
            let s = (tween.from + (1 - tween.from) * eased) * overshoot
            root.scale = SIMD3<Float>(repeating: s)
            growthScaleTween = t >= 1 ? nil : tween
            if t >= 1 { root.scale = [1, 1, 1] }
        }
        let pose = animator.step(deltaTime: deltaTime, rootPosition: root.position, rootYaw: Self.yaw(of: root.orientation), cameraPosition: cameraPosition)
        root.position = pose.rootPosition
        root.orientation = simd_quatf(angle: pose.rootYaw, axis: [0, 1, 0])
        body.scale = pose.bodyScale
        body.orientation = simd_quatf(angle: .pi / 2 + pose.bodyPitch, axis: [1, 0, 0])
        headPivot.orientation = simd_quatf(angle: pose.headYaw, axis: [0, 1, 0])
            * simd_quatf(angle: -pose.headPitch, axis: [1, 0, 0])
            * simd_quatf(angle: pose.headRoll, axis: [0, 0, 1])
        headPivot.position = [0, Float(morphology.headCenterHeight) + pose.headLift, Float(morphology.bodyLength) * 0.42 + pose.headForward]
        tailPivot.orientation = simd_quatf(angle: pose.tailYaw, axis: [0, 1, 0]) * simd_quatf(angle: pose.tailPitch, axis: [1, 0, 0])
        for (index, leg) in legs.enumerated() {
            leg.orientation = simd_quatf(angle: pose.legSwing[index], axis: [1, 0, 0])
        }
        eyeL.scale = [1, pose.eyeOpenLeft, 1]
        eyeR.scale = [1, pose.eyeOpenRight, 1]
        earL.orientation = simd_quatf(angle: -0.28 - pose.earSpread, axis: [0, 0, 1]) * simd_quatf(angle: pose.earPitch, axis: [1, 0, 0])
        earR.orientation = simd_quatf(angle: 0.28 + pose.earSpread, axis: [0, 0, 1]) * simd_quatf(angle: pose.earPitch, axis: [1, 0, 0])
    }
}
