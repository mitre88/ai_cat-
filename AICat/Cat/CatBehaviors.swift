import Foundation
import simd
import AICatCore

/// Per-frame pose produced by the animator and applied by the rig.
struct CatPose {
    var rootPosition: SIMD3<Float>
    var rootYaw: Float
    var bodyScale: SIMD3<Float>
    var bodyPitch: Float
    var headOrientation: simd_quatf
    var headLift: Float
    var headForward: Float
    var tailYaw: Float
    var tailPitch: Float
    var legSwing: [Float]
    var eyeOpen: (left: Float, right: Float)
    var earSpread: Float
    var earPitch: Float
}

/// Procedural animation: breathing, blinking, tail, gaze, walking and one-shot gestures.
/// Pure math over time; it knows nothing about RealityKit.
@MainActor
final class CatAnimator {
    var emotion: CatEmotion = .happy
    var gazeTarget: SIMD3<Float>?
    var walkTarget: SIMD3<Float>?
    var onArrive: (() -> Void)?

    private var time: Float = 0
    private var blinkTimer: Float = 2.5
    private var blinkRemaining: Float = 0
    private var gesture: CatGesture = .none
    private var gestureTime: Float = 0
    private var gestureDuration: Float = 1
    private var walkPhase: Float = 0
    private var legBlend: Float = 0
    private var headYaw: Float = 0
    private var headPitch: Float = 0
    private var earSpread: Float = 0
    private var earPitch: Float = 0

    private var bodyLength: Float = 0.18
    private var headCenterHeight: Float = 0.12

    func configure(morphology: Morphology) {
        bodyLength = Float(morphology.bodyLength)
        headCenterHeight = Float(morphology.headCenterHeight)
    }

    func play(_ gesture: CatGesture) {
        guard gesture != .none else { return }
        self.gesture = gesture
        gestureTime = 0
        gestureDuration = Self.duration(of: gesture)
    }

    static func duration(of gesture: CatGesture) -> Float {
        switch gesture {
        case .none: return 0
        case .nod: return 0.8
        case .jump: return 0.7
        case .tailWag: return 1.6
        case .headTilt: return 1.0
        case .stretch: return 1.4
        case .pounce: return 1.0
        case .sit: return 2.6
        case .shake: return 0.8
        }
    }

    /// Yaw (rotation about Y) of an orientation whose forward axis is +Z.
    func yaw(of orientation: simd_quatf) -> Float {
        let forward = orientation.act(SIMD3<Float>(0, 0, 1))
        return atan2(forward.x, forward.z)
    }

    func step(deltaTime dt: Float, rootPosition: SIMD3<Float>, rootYaw: Float, cameraPosition: SIMD3<Float>, headPivotWorld: SIMD3<Float>) -> CatPose {
        time += dt
        var position = rootPosition
        var yaw = rootYaw
        var legSwing: [Float] = [0, 0, 0, 0]

        // --- walking -------------------------------------------------------
        var walking = false
        if let target = walkTarget {
            var delta = target - position
            delta.y = 0
            let distance = simd_length(delta)
            if distance < 0.03 {
                walkTarget = nil
                let callback = onArrive
                onArrive = nil
                callback?()
            } else {
                walking = true
                let speed = 1.6 * bodyLength
                let step = min(speed * dt, distance)
                position += (delta / distance) * step
                let desiredYaw = atan2(delta.x, delta.z)
                yaw = Self.lerpAngle(yaw, desiredYaw, 1 - exp(-dt * 8))
                walkPhase += dt * 2 * .pi * 2.2
            }
        }
        legBlend += ((walking ? 1 : 0) - legBlend) * (1 - exp(-dt * 10))
        let stride: Float = 0.45 * legBlend
        legSwing[0] = stride * sin(walkPhase)
        legSwing[3] = stride * sin(walkPhase)
        legSwing[1] = stride * sin(walkPhase + .pi)
        legSwing[2] = stride * sin(walkPhase + .pi)
        position.y = 0.012 * bodyLength / 0.18 * abs(sin(walkPhase)) * legBlend

        // --- breathing -----------------------------------------------------
        let breath = sin(2 * .pi * 0.4 * time)
        var bodyScale = SIMD3<Float>(1 + 0.03 * breath, 1, 1 + 0.03 * breath)
        var bodyPitch: Float = 0

        // --- blinking ------------------------------------------------------
        blinkTimer -= dt
        if blinkTimer <= 0 {
            blinkRemaining = 0.13
            blinkTimer = Float.random(in: 2.5...5.5)
        }
        if blinkRemaining > 0 { blinkRemaining -= dt }
        var eyes = baseEyeOpenness()
        if blinkRemaining > 0 {
            eyes = (0.12, 0.12)
        }

        // --- ears & tail by emotion ----------------------------------------
        let earTargets = earTargetsForEmotion()
        earSpread += (earTargets.spread - earSpread) * (1 - exp(-dt * 6))
        earPitch += (earTargets.pitch - earPitch) * (1 - exp(-dt * 6))
        let tail = tailParameters()
        var tailYaw = tail.amplitude * sin(2 * .pi * tail.frequency * time)
        var tailPitch = tail.pitch

        // --- gaze ----------------------------------------------------------
        let lookPoint = gazeTarget ?? cameraPosition
        let local = Self.rotateY(lookPoint - position, by: -yaw)
        let headLocal = SIMD3<Float>(0, headCenterHeight, bodyLength * 0.42)
        let v = local - headLocal
        let horizontal = max(sqrt(v.x * v.x + v.z * v.z), 0.001)
        let desiredYaw = max(min(atan2(v.x, v.z), 0.65), -0.65)
        let desiredPitch = max(min(atan2(v.y, horizontal), 0.5), -0.45)
        headYaw += (desiredYaw - headYaw) * (1 - exp(-dt * 5))
        headPitch += (desiredPitch - headPitch) * (1 - exp(-dt * 5))
        var extraYaw: Float = 0
        var extraPitch: Float = 0
        var roll: Float = 0
        var headLift: Float = 0
        var headForward: Float = 0

        // --- one-shot gestures ---------------------------------------------
        if gesture != .none {
            gestureTime += dt
            let t = min(gestureTime / gestureDuration, 1)
            let bump = sin(t * .pi)
            switch gesture {
            case .nod:
                extraPitch = -0.35 * sin(2 * .pi * t) * (1 - t)
            case .jump:
                position.y += 0.6 * bodyLength * bump
                legSwing = legSwing.map { $0 - 0.4 * bump }
            case .tailWag:
                tailYaw = tail.amplitude * 2.5 * sin(2 * .pi * 3.0 * time)
            case .headTilt:
                roll = 0.4 * bump
            case .stretch:
                bodyScale = SIMD3<Float>(bodyScale.x, 1 + 0.18 * bump, bodyScale.z)
                headForward = 0.08 * bodyLength * bump
                headLift = -0.12 * bodyLength * bump
                tailPitch += 0.6 * bump
            case .pounce:
                if t < 0.4 {
                    let c = t / 0.4
                    headLift = -0.15 * bodyLength * c
                    bodyScale = SIMD3<Float>(bodyScale.x, 1, bodyScale.z * (1 - 0.1 * c))
                } else {
                    let h = (t - 0.4) / 0.6
                    position.y += 0.45 * bodyLength * sin(h * .pi)
                    let forward = SIMD3<Float>(sin(yaw), 0, cos(yaw))
                    position += forward * (0.5 * bodyLength * dt / 0.6)
                }
            case .sit:
                let hold = t < 0.2 ? t / 0.2 : (t > 0.85 ? (1 - t) / 0.15 : 1)
                bodyPitch = -0.45 * hold
                legSwing[2] = -1.1 * hold
                legSwing[3] = -1.1 * hold
                headLift = 0.08 * bodyLength * hold
                headForward = -0.1 * bodyLength * hold
            case .shake:
                extraYaw = 0.5 * sin(2 * .pi * 4 * t) * (1 - t)
            case .none:
                break
            }
            if t >= 1 { gesture = .none }
        }

        let headOrientation = simd_quatf(angle: headYaw + extraYaw, axis: [0, 1, 0])
            * simd_quatf(angle: -(headPitch + extraPitch), axis: [1, 0, 0])
            * simd_quatf(angle: roll, axis: [0, 0, 1])

        return CatPose(
            rootPosition: position,
            rootYaw: yaw,
            bodyScale: bodyScale,
            bodyPitch: bodyPitch,
            headOrientation: headOrientation,
            headLift: headLift,
            headForward: headForward,
            tailYaw: tailYaw,
            tailPitch: tailPitch,
            legSwing: legSwing,
            eyeOpen: eyes,
            earSpread: earSpread,
            earPitch: earPitch
        )
    }

    // MARK: Emotion tables

    private func baseEyeOpenness() -> (left: Float, right: Float) {
        switch emotion {
        case .happy: return (0.85, 0.85)
        case .curious: return (1.15, 1.15)
        case .proud: return (0.7, 0.7)
        case .thinking: return (0.55, 1.0)
        case .sleepy: return (0.3, 0.3)
        case .excited: return (1.2, 1.2)
        case .sad: return (0.9, 0.9)
        }
    }

    private func earTargetsForEmotion() -> (spread: Float, pitch: Float) {
        switch emotion {
        case .happy: return (0, 0)
        case .curious: return (-0.05, -0.25)
        case .proud: return (0, -0.1)
        case .thinking: return (0.1, 0.1)
        case .sleepy: return (0.3, 0.2)
        case .excited: return (-0.1, -0.3)
        case .sad: return (0.55, 0.35)
        }
    }

    private func tailParameters() -> (amplitude: Float, frequency: Float, pitch: Float) {
        switch emotion {
        case .happy: return (0.35, 1.1, 0.2)
        case .curious: return (0.25, 0.9, 0.35)
        case .proud: return (0.4, 1.0, 0.5)
        case .thinking: return (0.15, 0.6, 0.1)
        case .sleepy: return (0.08, 0.4, -0.2)
        case .excited: return (0.7, 2.2, 0.4)
        case .sad: return (0.1, 0.5, -0.45)
        }
    }

    // MARK: Math helpers

    static func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        var delta = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return a + delta * t
    }

    static func rotateY(_ v: SIMD3<Float>, by angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3<Float>(c * v.x + s * v.z, v.y, -s * v.x + c * v.z)
    }
}
