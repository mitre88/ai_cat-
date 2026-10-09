import Foundation
import RealityKit
import UIKit
import AICatCore

/// Sun (directional light with a fixed shadow box over the set), a soft sky-tinted fill and a cool rim light
/// from behind. The sun can rise with the hinge angle.
@MainActor
final class Lighting {
    let root = Entity()
    private let sun = Entity()
    private let fill = Entity()
    private let rim = Entity()
    private var elevation = Float(ProceduralSky.defaultSunElevation)   // radians above the horizon; the sky's sun uses the same
    private var azimuth = Float(ProceduralSky.defaultSunAzimuth)       // radians around the Y axis

    /// Point lights are in lumens: 40 000 lm at ~3.7 m is ≈ 230 lux, a 5–7 % fill against the 3 200–4 800 lux sun.
    static let fillLumens: Float = 40_000

    init() {
        root.name = "lighting"
        sun.name = "sun"
        sun.components.set(DirectionalLightComponent(color: .white, intensity: 4500, isRealWorldProxy: false))
        // Fixed orthographic shadow box centred on the set (the sun entity sits 8 m out, looking at the origin):
        // the shadow map covers the ±5 m play area instead of the whole camera frustum, so shadows stay crisp.
        // If shadows vanish on device, fall back to `.automatic(maximumDistance: 10)`.
        sun.components.set(DirectionalLightComponent.Shadow(shadowProjection: .fixed(zNear: 0.5, zFar: 20, orthographicScale: 10), depthBias: 1.2, cullMode: nil))
        fill.name = "fill"
        fill.components.set(PointLightComponent(color: UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1), intensity: Self.fillLumens, attenuationRadius: 14))
        fill.position = [-2.5, 2.5, 2.5]
        rim.name = "rim"
        rim.components.set(DirectionalLightComponent(color: UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1), intensity: 1100, isRealWorldProxy: false))
        rim.look(at: .zero, from: [-2.0, 2.4, -3.2], relativeTo: nil)
        root.addChild(sun)
        root.addChild(fill)
        root.addChild(rim)
        applySun()
    }

    /// openness 0 (closed) … 1 (flat): sunrise effect driven by the hinge. Layout never depends on it.
    func setOpenness(_ openness: Double) {
        let t = Float(min(max(openness, 0), 1))
        elevation = 0.15 + 0.75 * t
        applySun(warmth: 1 - t)
    }

    func setTheme(skyTint: UIColor) {
        fill.components.set(PointLightComponent(color: skyTint, intensity: Self.fillLumens, attenuationRadius: 14))
        rim.components.set(DirectionalLightComponent(color: skyTint, intensity: 1100, isRealWorldProxy: false))
    }

    private func applySun(warmth: Float = 0) {
        let distance: Float = 8
        let y = sin(elevation) * distance
        let horizontal = cos(elevation) * distance
        let position = SIMD3<Float>(sin(azimuth) * horizontal, y, cos(azimuth) * horizontal)
        sun.look(at: .zero, from: position, relativeTo: nil)
        let color = UIColor(red: 1.0, green: CGFloat(1.0 - 0.25 * warmth), blue: CGFloat(1.0 - 0.45 * warmth), alpha: 1)
        sun.components.set(DirectionalLightComponent(color: color, intensity: 3200 + 1600 * (1 - warmth), isRealWorldProxy: false))
    }
}
