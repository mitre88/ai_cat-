import RealityKit
import SwiftUI

/// Every material of the game is built here, so a wrong RealityKit material API is fixed in one place.
enum Materials {
    static func pbr(_ color: UIColor, roughness: Float = 0.7, metallic: Float = 0, sheen: UIColor? = nil,
                    emissive: UIColor? = nil, emissiveIntensity: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color)
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)
        material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: metallic)
        if let sheen {
            material.sheen = PhysicallyBasedMaterial.SheenColor(tint: sheen)
        }
        if let emissive {
            material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: emissive)
            material.emissiveIntensity = emissiveIntensity
        }
        return material
    }

    static func pbr(_ color: Color, roughness: Float = 0.7, metallic: Float = 0) -> PhysicallyBasedMaterial {
        pbr(UIColor(color), roughness: roughness, metallic: metallic)
    }

    /// Black fur with a soft sheen so the silhouette reads against dark backgrounds.
    static var fur: PhysicallyBasedMaterial {
        pbr(UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1), roughness: 0.88, sheen: UIColor(white: 0.32, alpha: 1))
    }

    static var eye: PhysicallyBasedMaterial {
        let green = UIColor(red: 0.16, green: 0.80, blue: 0.62, alpha: 1)
        return pbr(green, roughness: 0.25, emissive: green, emissiveIntensity: 0.6)
    }

    static var pupil: PhysicallyBasedMaterial {
        pbr(UIColor(white: 0.02, alpha: 1), roughness: 0.2)
    }

    static var nose: PhysicallyBasedMaterial {
        pbr(UIColor(red: 0.93, green: 0.55, blue: 0.62, alpha: 1), roughness: 0.5)
    }

    static var innerEar: PhysicallyBasedMaterial {
        pbr(UIColor(red: 0.75, green: 0.45, blue: 0.52, alpha: 1), roughness: 0.8)
    }

    static func ground(_ color: Color) -> PhysicallyBasedMaterial {
        pbr(UIColor(color), roughness: 0.95)
    }

    static func matte(_ color: Color) -> PhysicallyBasedMaterial {
        pbr(UIColor(color), roughness: 0.85)
    }

    static func glossy(_ color: Color) -> PhysicallyBasedMaterial {
        pbr(UIColor(color), roughness: 0.3)
    }

    static func glowing(_ color: Color, intensity: Float = 1.2) -> PhysicallyBasedMaterial {
        pbr(UIColor(color), roughness: 0.4, emissive: UIColor(color), emissiveIntensity: intensity)
    }
}
