import RealityKit
import UIKit

/// Sun (directional light with shadows) and a soft fill. The sun can rise with the hinge angle.
@MainActor
final class Lighting {
    let root = Entity()
    private let sun = Entity()
    private let fill = Entity()
    private var elevation: Float = 0.9      // radians above the horizon
    private var azimuth: Float = 0.7        // radians around the Y axis

    init() {
        root.name = "lighting"
        sun.name = "sun"
        sun.components.set(DirectionalLightComponent(color: .white, intensity: 4500, isRealWorldProxy: false))
        sun.components.set(DirectionalLightComponent.Shadow(maximumDistance: 14, depthBias: 1.5))
        fill.name = "fill"
        fill.components.set(PointLightComponent(color: UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1), intensity: 900, attenuationRadius: 14))
        fill.position = [-2.5, 2.5, 2.5]
        root.addChild(sun)
        root.addChild(fill)
        applySun()
    }

    /// openness 0 (closed) … 1 (flat): sunrise effect driven by the hinge. Layout never depends on it.
    func setOpenness(_ openness: Double) {
        let t = Float(min(max(openness, 0), 1))
        elevation = 0.15 + 0.75 * t
        applySun(warmth: 1 - t)
    }

    func setTheme(skyTint: UIColor) {
        fill.components.set(PointLightComponent(color: skyTint, intensity: 900, attenuationRadius: 14))
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
