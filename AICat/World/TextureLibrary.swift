import RealityKit
import AICatCore

/// Uploads the procedural textures (`ProceduralTextures` in AICatCore) once per launch, generated on a
/// background task and tagged with the right semantic (colour or normal map), then caches them. Materials
/// fall back to flat colour until a texture exists, so nothing ever waits on this class.
@MainActor
final class TextureLibrary {
    static let shared = TextureLibrary()

    private var cache: [TextureKind: TextureResource] = [:]
    private var loads: [TextureKind: Task<TextureResource?, Never>] = [:]

    func texture(_ kind: TextureKind) -> TextureResource? { cache[kind] }

    /// Generates and uploads the textures that are not cached yet. Every missing texture is generated at the
    /// same time (one detached task each, so a world's set takes about one texture's time on a multi-core
    /// phone); a second caller for a texture already being generated waits for it instead of returning
    /// without it. Safe to call many times.
    func prepare(_ kinds: [TextureKind]) async {
        var pending: [(TextureKind, Task<TextureResource?, Never>)] = []
        for kind in kinds where cache[kind] == nil {
            if let running = loads[kind] {
                pending.append((kind, running))
                continue
            }
            let load = Task<TextureResource?, Never> { @MainActor in
                let image = await Task.detached(priority: .userInitiated) { ProceduralImages.image(for: kind) }.value
                guard let image else { return nil }
                let options = TextureResource.CreateOptions(semantic: Self.semantic(for: kind))
                return try? await TextureResource(image: image, withName: "aicat.\(kind.rawValue)", options: options)
            }
            loads[kind] = load
            pending.append((kind, load))
        }
        for (kind, load) in pending {
            if let resource = await load.value {
                cache[kind] = resource
            }
            if loads[kind] == load {
                loads[kind] = nil
            }
        }
    }

    /// How RealityKit should interpret each texture: normal maps as normals, the contact shadow as the
    /// opacity map it feeds (`PhysicallyBasedMaterial.Opacity.textureSemantic`), everything else as colour.
    static func semantic(for kind: TextureKind) -> TextureResource.Semantic {
        if kind.isNormalMap { return .normal }
        if kind == .blobShadow { return PhysicallyBasedMaterial.Opacity.textureSemantic }
        return .color
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

    /// Textures of the props each world is dressed with (`SceneBuilder`) and of its challenge pieces
    /// (baskets, pedestals). Stone is everywhere because every pedestal is stone.
    static func props(for theme: WorldTheme) -> [TextureKind] {
        switch theme {
        case .garden: return [.bark, .barkNormal, .leaves, .wicker, .fruit, .fruitNormal, .stone, .stoneNormal]
        case .library: return [.wood, .woodNormal, .carpet, .stone, .stoneNormal]
        case .workshop: return [.wood, .woodNormal, .metal, .stone, .stoneNormal]
        case .trail: return [.bark, .barkNormal, .leaves, .sand, .stone, .stoneNormal]
        case .maze: return [.leaves, .stone, .stoneNormal]
        case .factory: return [.metal, .stone, .stoneNormal]
        case .lookout: return [.leaves, .wood, .woodNormal, .stone, .stoneNormal]
        case .theater: return [.wood, .woodNormal, .carpet, .metal, .stone, .stoneNormal]
        case .plaza: return [.wood, .woodNormal, .metal, .stone, .stoneNormal]
        case .lab: return [.metal, .stone, .stoneNormal]
        }
    }

    /// Everything a world needs: its ground, its props, AI CAT's fur and the contact shadow (duplicates are fine).
    static func kinds(for theme: WorldTheme) -> [TextureKind] {
        let ground = ground(for: theme)
        var kinds: [TextureKind] = [ground.color, .fur, .furNormal, .blobShadow]
        if let normal = ground.normal { kinds.append(normal) }
        kinds += props(for: theme)
        return kinds
    }
}
