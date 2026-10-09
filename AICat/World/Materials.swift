import RealityKit
import SwiftUI
import AICatCore

/// Every material of the game is built here, so a wrong RealityKit material API is fixed in one place.
///
/// Textured materials multiply a palette tint by a procedural *structure* texture (mean brightness ≈ 1), so the
/// world keeps its colours and gains grain; a normal map adds relief where the surface has it.
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

    /// A PBR material with a procedural colour texture (and optionally a normal map) tinted by `tint`,
    /// repeated `repeats` times across the UV square. Falls back to the flat tint until the texture exists.
    @MainActor
    static func textured(_ tint: UIColor, color: TextureKind, normal: TextureKind? = nil, roughness: Float = 0.9,
                         metallic: Float = 0, repeats: Float = 1, sheen: UIColor? = nil) -> PhysicallyBasedMaterial {
        var material = pbr(tint, roughness: roughness, metallic: metallic, sheen: sheen)
        let library = TextureLibrary.shared
        if let resource = library.texture(color) {
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: tint, texture: MaterialParameters.Texture(resource))
        }
        if let normal, let resource = library.texture(normal) {
            material.normal = PhysicallyBasedMaterial.Normal(texture: MaterialParameters.Texture(resource))
        }
        material.textureCoordinateTransform = PhysicallyBasedMaterial.TextureCoordinateTransform(offset: .zero, scale: [repeats, repeats], rotation: 0)
        return material
    }

    /// The ground of a world: the palette colour multiplied by the theme's grass, wood, stone, metal, sand,
    /// carpet or tile texture, with a normal map where the surface has relief.
    @MainActor
    static func ground(theme: WorldTheme, palette: WorldPalette) -> PhysicallyBasedMaterial {
        let surface = TextureLibrary.ground(for: theme)
        let roughness: Float = theme == .factory ? 0.45 : (theme == .lab ? 0.35 : 0.95)
        return textured(UIColor(palette.ground), color: surface.color, normal: surface.normal, roughness: roughness, repeats: surface.repeats)
    }

    // MARK: Prop surfaces

    /// Planks with grain and seams (benches, shelves, stages).
    @MainActor
    static func wood(_ tint: Color, repeats: Float = 2) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .wood, normal: .woodNormal, roughness: 0.75, repeats: repeats)
    }

    /// Flagstones with bevelled edges (pedestals, basins, towers, rocks).
    @MainActor
    static func stone(_ tint: Color, repeats: Float = 2) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .stone, normal: .stoneNormal, roughness: 0.9, repeats: repeats)
    }

    /// Tree trunks: vertical ridges with a normal map.
    @MainActor
    static func bark(_ tint: Color, repeats: Float = 2) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .bark, normal: .barkNormal, roughness: 0.95, repeats: repeats)
    }

    /// Canopies, hedges and bushes.
    @MainActor
    static func leaves(_ tint: Color, repeats: Float = 3) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .leaves, roughness: 0.9, repeats: repeats)
    }

    /// Woven baskets.
    @MainActor
    static func wicker(_ tint: Color, repeats: Float = 4) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .wicker, roughness: 0.85, repeats: repeats)
    }

    /// Brushed metal (gears, chimneys, lamp posts, lab tables).
    @MainActor
    static func metal(_ tint: Color, repeats: Float = 2) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .metal, roughness: 0.4, metallic: 0.6, repeats: repeats)
    }

    /// Rugs and curtains.
    @MainActor
    static func carpet(_ tint: Color, repeats: Float = 4) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .carpet, roughness: 0.95, repeats: repeats)
    }

    /// Fruit peel: pores and a faint mottle under a glossy finish; the tint is the fruit's colour.
    @MainActor
    static func fruit(_ tint: Color) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .fruit, normal: .fruitNormal, roughness: 0.32, repeats: 2)
    }

    /// Dry earth paths.
    @MainActor
    static func sand(_ tint: Color, repeats: Float = 3) -> PhysicallyBasedMaterial {
        textured(UIColor(tint), color: .sand, roughness: 0.95, repeats: repeats)
    }

    // MARK: AI CAT

    /// Black fur: fine strands in the colour and normal textures plus a soft sheen, so the silhouette reads
    /// against dark backgrounds and the coat catches the rim light. The tint keeps the kitten charcoal-black;
    /// the texture's range (0.55–1.0) is what makes the strands visible.
    @MainActor
    static var fur: PhysicallyBasedMaterial {
        textured(UIColor(red: 0.17, green: 0.17, blue: 0.20, alpha: 1), color: .fur, normal: .furNormal, roughness: 0.82,
                 repeats: 3, sheen: UIColor(white: 0.34, alpha: 1))
    }

    /// Soft contact shadow: an unlit, transparent black disc with a radial falloff that works on every device.
    /// `opacity` is the darkness at the centre.
    @MainActor
    static func blobShadow(opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let resource = TextureLibrary.shared.texture(.blobShadow) {
            material.color = UnlitMaterial.BaseColor(tint: .black, texture: MaterialParameters.Texture(resource))
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        } else {
            material.color = UnlitMaterial.BaseColor(tint: .black, texture: nil)
            material.blending = .transparent(opacity: .init(floatLiteral: opacity * 0.45))
        }
        material.writesDepth = false
        return material
    }

    /// The shadow under AI CAT.
    @MainActor
    static var blobShadow: UnlitMaterial { blobShadow(opacity: 0.55) }

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

    // MARK: Flat materials

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
