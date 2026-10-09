import RealityKit
import AICatCore

/// The procedural textures the worlds use. Generated once per launch on a background task, uploaded with the
/// right semantic (colour or normal map) and cached; materials fall back to flat colour until they are ready.
enum TextureKind: String, CaseIterable, Sendable {
    case grass, stone, wood, metal, carpet, labTile, sand, fur, blobShadow
    case grassNormal, stoneNormal, woodNormal, furNormal

    var isNormalMap: Bool { rawValue.hasSuffix("Normal") }
}

@MainActor
final class TextureLibrary {
    static let shared = TextureLibrary()

    private var cache: [TextureKind: TextureResource] = [:]
    private var inFlight: Set<TextureKind> = []

    func texture(_ kind: TextureKind) -> TextureResource? { cache[kind] }

    /// Generates and uploads the textures that are not cached yet. Safe to call many times.
    func prepare(_ kinds: [TextureKind]) async {
        for kind in kinds where cache[kind] == nil && !inFlight.contains(kind) {
            inFlight.insert(kind)
            let image = await Task.detached(priority: .userInitiated) { ProceduralImages.image(for: kind) }.value
            if let image {
                let options = TextureResource.CreateOptions(semantic: kind.isNormalMap ? .normal : .color)
                if let resource = try? await TextureResource(image: image, withName: "aicat.\(kind.rawValue)", options: options) {
                    cache[kind] = resource
                }
            }
            inFlight.remove(kind)
        }
    }

    /// Ground surface of a theme: colour texture, normal map and how many times it repeats across the set.
    static func ground(for theme: WorldTheme) -> (color: TextureKind, normal: TextureKind?, repeats: Float) {
        switch theme {
        case .garden, .maze, .trail: return (.grass, .grassNormal, 9)
        case .library: return (.wood, .woodNormal, 7)
        case .workshop, .plaza: return (.stone, .stoneNormal, 8)
        case .factory: return (.metal, nil, 6)
        case .lookout: return (.sand, nil, 8)
        case .theater: return (.carpet, nil, 10)
        case .lab: return (.labTile, nil, 8)
        }
    }

    /// Everything a world needs: its ground, AI CAT's fur and the contact shadow.
    static func kinds(for theme: WorldTheme) -> [TextureKind] {
        let ground = ground(for: theme)
        return [ground.color, ground.normal, .fur, .furNormal, .blobShadow].compactMap { $0 }
    }
}
