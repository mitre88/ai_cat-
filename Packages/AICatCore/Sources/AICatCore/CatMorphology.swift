import Foundation

/// AI CAT's body proportions as a function of growth. Every value is in metres (ratios are unit-less).
/// The procedural rig and the camera read these so the world keeps coherent proportions.
public struct CatMorphology: Equatable, Sendable {
    public var bodyLength: Double
    public var headRadiusRatio: Double   // head radius / body length
    public var legLength: Double
    public var earScale: Double
    public var tailLength: Double
    public var eyeRadiusRatio: Double    // eye radius / head radius

    public init(bodyLength: Double, headRadiusRatio: Double, legLength: Double, earScale: Double, tailLength: Double, eyeRadiusRatio: Double) {
        self.bodyLength = bodyLength
        self.headRadiusRatio = headRadiusRatio
        self.legLength = legLength
        self.earScale = earScale
        self.tailLength = tailLength
        self.eyeRadiusRatio = eyeRadiusRatio
    }

    public static let kitten = CatMorphology(bodyLength: 0.18, headRadiusRatio: 0.42, legLength: 0.05, earScale: 1.30, tailLength: 0.10, eyeRadiusRatio: 0.28)
    public static let adult = CatMorphology(bodyLength: 0.45, headRadiusRatio: 0.30, legLength: 0.16, earScale: 1.00, tailLength: 0.30, eyeRadiusRatio: 0.18)

    /// p(ĝ) = p_kitten + (p_adult − p_kitten) · smoothstep(ĝ)
    public static func interpolated(growth: Double) -> CatMorphology {
        let s = GrowthModel.smoothstep(growth)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * s }
        return CatMorphology(
            bodyLength: mix(kitten.bodyLength, adult.bodyLength),
            headRadiusRatio: mix(kitten.headRadiusRatio, adult.headRadiusRatio),
            legLength: mix(kitten.legLength, adult.legLength),
            earScale: mix(kitten.earScale, adult.earScale),
            tailLength: mix(kitten.tailLength, adult.tailLength),
            eyeRadiusRatio: mix(kitten.eyeRadiusRatio, adult.eyeRadiusRatio)
        )
    }

    public static func forXP(_ xp: Double) -> CatMorphology {
        interpolated(growth: GrowthModel.normalizedGrowth(xp: xp))
    }

    // MARK: Derived dimensions used by the rig

    public var headRadius: Double { bodyLength * headRadiusRatio }
    public var bodyRadius: Double { bodyLength * 0.30 }
    public var eyeRadius: Double { headRadius * eyeRadiusRatio }
    public var earHeight: Double { headRadius * 0.95 * earScale }
    public var earRadius: Double { headRadius * 0.38 * earScale }
    public var legRadius: Double { bodyRadius * 0.30 }
    public var tailRadius: Double { bodyRadius * 0.22 }
    public var noseRadius: Double { headRadius * 0.14 }
    /// Height of the body centre above the ground.
    public var bodyCenterHeight: Double { legLength + bodyRadius }
    /// Height of the head centre above the ground.
    public var headCenterHeight: Double { bodyCenterHeight + bodyRadius * 0.55 + headRadius * 0.75 }
    /// Approximate top of the ears above the ground (camera framing).
    public var standingHeight: Double { headCenterHeight + headRadius + earHeight * 0.6 }
}
