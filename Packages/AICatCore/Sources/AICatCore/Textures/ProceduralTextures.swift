import Foundation

/// The procedural textures of the worlds. Every surface is a formula over tileable value noise, so no image
/// ships with the app and each world still has grain, grass and grit. The formulas live here (Foundation only)
/// so `swift test` checks tileability, ranges and normal-map geometry; the app wraps the pixels in a CGImage.
///
/// Colour textures are *structure*, not colour: their mean brightness is close to 1 with a faint hue, and the
/// material's tint (the world palette) multiplies them, so each world keeps its colour identity. The look is
/// a felt diorama: broad, soft, matte shapes; nothing so fine that it reads as static on a phone.
public enum TextureKind: String, CaseIterable, Sendable {
    // colour (premultiplied RGBA, opaque)
    case grass, stone, wood, metal, carpet, labTile, sand, fur, bark, leaves, wicker, fruit
    // falloff in every channel (premultiplied white): opacity map of the contact shadow
    case blobShadow
    // tangent-space normal maps
    case grassNormal, stoneNormal, woodNormal, furNormal, barkNormal, fruitNormal

    public var isNormalMap: Bool { rawValue.hasSuffix("Normal") }

    /// Pixels per side. Grounds and the coat fill the screen; props are small, the shadow is a smooth gradient.
    public var preferredSize: Int {
        switch self {
        case .bark, .barkNormal, .leaves, .wicker, .fruit, .fruitNormal: return 256
        case .blobShadow: return 128
        default: return 512
        }
    }

    /// A stable seed per kind (`hashValue` changes every launch; textures must not).
    public var seed: UInt32 {
        UInt32(TextureKind.allCases.firstIndex(of: self) ?? 0) &* 7919 &+ 13
    }
}

/// Row-major, premultiplied RGBA8 pixels.
public struct RGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// The four channels of pixel (x, y).
    public func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * width + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }
}

public enum ProceduralTextures {
    public typealias RGB = (r: Double, g: Double, b: Double)

    /// Normal-map strength (height gradient multiplier) per kind; larger = deeper relief.
    static func normalStrength(_ kind: TextureKind) -> Double {
        switch kind {
        case .stoneNormal: return 1.2
        case .grassNormal: return 0.8
        case .woodNormal: return 0.9
        case .barkNormal: return 1.2
        case .fruitNormal: return 1.0
        default: return 0.8
        }
    }

    /// Renders `kind` at `size` pixels per side (its preferred size by default). Pure: same input, same bytes.
    public static func render(_ kind: TextureKind, size: Int? = nil) -> RGBAImage {
        let size = max(4, size ?? kind.preferredSize)
        let field = NoiseField(size: size, seed: kind.seed)
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        if kind.isNormalMap {
            paintNormal(&pixels, size, strength: normalStrength(kind)) { field.height(kind, $0, $1) }
        } else if kind == .blobShadow {
            paintAlpha(&pixels, size) { field.blob($0, $1) }
        } else {
            paintColor(&pixels, size) { field.color(kind, $0, $1) }
        }
        return RGBAImage(width: size, height: size, pixels: pixels)
    }

    // MARK: Pixel painters

    private static func paintColor(_ pixels: inout [UInt8], _ size: Int, _ color: (Double, Double) -> RGB) {
        for y in 0..<size {
            for x in 0..<size {
                let c = color(Double(x) / Double(size), Double(y) / Double(size))
                let index = (y * size + x) * 4
                pixels[index] = byte(c.r)
                pixels[index + 1] = byte(c.g)
                pixels[index + 2] = byte(c.b)
                pixels[index + 3] = 255
            }
        }
    }

    /// Premultiplied white with the alpha the closure returns: every channel carries the falloff, so the
    /// texture works both as an opacity map (whichever channel the renderer samples) and as a colour map
    /// tinted black.
    private static func paintAlpha(_ pixels: inout [UInt8], _ size: Int, _ alpha: (Double, Double) -> Double) {
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                let a = byte(alpha(Double(x) / Double(size), Double(y) / Double(size)))
                pixels[index] = a
                pixels[index + 1] = a
                pixels[index + 2] = a
                pixels[index + 3] = a
            }
        }
    }

    /// Tangent-space normal map from a tileable height field, encoded as (n + 1) / 2 with
    /// n = normalize(−∂h/∂u·s, +∂h/∂row·s, 1): RealityKit (like USD) reads normal maps OpenGL-style, +Y
    /// towards increasing v, and v = 0 is the bottom row of the image, so the green channel takes the
    /// gradient along increasing row index. Central differences wrap, so the map tiles like the height field.
    /// If the relief looks inverted on the device (stone bevels lit from the wrong side), flip `greenSign`.
    static let greenSign: Double = 1

    private static func paintNormal(_ pixels: inout [UInt8], _ size: Int, strength: Double, _ height: (Double, Double) -> Double) {
        var heights = [Double](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                heights[y * size + x] = height(Double(x) / Double(size), Double(y) / Double(size))
            }
        }
        func h(_ x: Int, _ y: Int) -> Double {
            heights[((y + size) % size) * size + ((x + size) % size)]
        }
        for y in 0..<size {
            for x in 0..<size {
                let dx = (h(x + 1, y) - h(x - 1, y)) * Double(size) / 2
                let dy = (h(x, y + 1) - h(x, y - 1)) * Double(size) / 2
                let nx = -dx * strength / 64
                let ny = greenSign * dy * strength / 64
                let length = (nx * nx + ny * ny + 1).squareRoot()
                let index = (y * size + x) * 4
                pixels[index] = byte((nx / length) * 0.5 + 0.5)
                pixels[index + 1] = byte((ny / length) * 0.5 + 0.5)
                pixels[index + 2] = byte((1 / length) * 0.5 + 0.5)
                pixels[index + 3] = 255
            }
        }
    }

    static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}

/// Tileable value noise on a wrapping lattice, plus the surface formulas. Every formula is periodic in
/// u and v with period 1, so `f(u + 1, v) == f(u, v)`: textures repeat seamlessly across the ground.
public struct NoiseField: Sendable {
    public let size: Int
    public let seed: UInt32

    public init(size: Int, seed: UInt32) {
        self.size = size
        self.seed = seed
    }

    // MARK: Noise

    /// Integer hash in [0, 1): the lattice values.
    public func hash(_ x: Int, _ y: Int, _ salt: UInt32) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 374_761_393 &+ UInt32(truncatingIfNeeded: y) &* 668_265_263 &+ seed &* 2_246_822_519 &+ salt &* 3_266_489_917
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFFFF) / Double(0x1000000)
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    private func wrap(_ i: Int, _ n: Int) -> Int { ((i % n) + n) % n }

    /// Value noise in [0, 1] that tiles every 1.0 in u and v for any integer cell counts.
    public func noise(_ u: Double, _ v: Double, cellsX: Int, cellsY: Int, salt: UInt32 = 0) -> Double {
        let px = u * Double(cellsX)
        let py = v * Double(cellsY)
        let ix = Int(px.rounded(.down))
        let iy = Int(py.rounded(.down))
        let fx = smooth(px - Double(ix))
        let fy = smooth(py - Double(iy))
        func corner(_ cx: Int, _ cy: Int) -> Double {
            hash(wrap(cx, cellsX), wrap(cy, cellsY), salt)
        }
        let top = corner(ix, iy) + (corner(ix + 1, iy) - corner(ix, iy)) * fx
        let bottom = corner(ix, iy + 1) + (corner(ix + 1, iy + 1) - corner(ix, iy + 1)) * fx
        return top + (bottom - top) * fy
    }

    /// Fractal sum of `octaves` noises, each twice as fine and half as strong; stays in [0, 1].
    public func fbm(_ u: Double, _ v: Double, cells: Int, octaves: Int, salt: UInt32 = 0) -> Double {
        var total = 0.0
        var amplitude = 0.5
        var sum = 0.0
        var c = cells
        for octave in 0..<octaves {
            total += noise(u, v, cellsX: c, cellsY: c, salt: salt &+ UInt32(octave)) * amplitude
            sum += amplitude
            amplitude *= 0.5
            c *= 2
        }
        return total / sum
    }

    private func mix(_ a: ProceduralTextures.RGB, _ b: ProceduralTextures.RGB, _ t: Double) -> ProceduralTextures.RGB {
        (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    private func scale(_ c: ProceduralTextures.RGB, _ k: Double) -> ProceduralTextures.RGB { (c.r * k, c.g * k, c.b * k) }

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    private func cell(_ x: Double, _ n: Int) -> Int { wrap(Int(x.rounded(.down)), n) }

    private func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    // MARK: Dispatch

    /// Colour of a colour texture at (u, v); every channel in [0, 1].
    public func color(_ kind: TextureKind, _ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        switch kind {
        case .grass: return grass(u, v)
        case .stone: return stone(u, v)
        case .wood: return wood(u, v)
        case .metal: return metal(u, v)
        case .carpet: return carpet(u, v)
        case .labTile: return labTile(u, v)
        case .sand: return sand(u, v)
        case .fur: return fur(u, v)
        case .bark: return bark(u, v)
        case .leaves: return leaves(u, v)
        case .wicker: return wicker(u, v)
        case .fruit: return fruit(u, v)
        case .blobShadow, .grassNormal, .stoneNormal, .woodNormal, .furNormal, .barkNormal, .fruitNormal:
            let a = blob(u, v)
            return (a, a, a)
        }
    }

    /// Height field (in [0, 1]) behind a normal map.
    public func height(_ kind: TextureKind, _ u: Double, _ v: Double) -> Double {
        switch kind {
        case .grassNormal: return grassHeight(u, v)
        case .stoneNormal: return stoneHeight(u, v)
        case .woodNormal: return woodHeight(u, v)
        case .furNormal: return furHeight(u, v)
        case .barkNormal: return barkHeight(u, v)
        case .fruitNormal: return fruitHeight(u, v)
        default: return 0.5
        }
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// Distance from the centre of a cell to its rounded edge (0 at the centre, 1 on the edge of a rounded
    /// square, more in the corners): a superellipse, so cobbles and tiles get soft rounded corners.
    private func roundedCell(_ u: Double, _ v: Double, cells: Int) -> Double {
        let fu = fract(u * Double(cells)) - 0.5
        let fv = fract(v * Double(cells)) - 0.5
        return pow(pow(abs(fu), 4) + pow(abs(fv), 4), 0.25) * 2
    }

    // MARK: Surfaces (colour) — soft and matte, like felt and paper: broad low-frequency shapes, no fine
    // grain that reads as static. Mean brightness ≈ 0.85–0.95; the palette tint supplies the colour.

    /// Meadow: very broad, gentle fields of two greens, sparse small clover dots and a whisper of mottle.
    /// No blades, and the fields are wide and faint so the ground never reads as camouflage.
    public func grass(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let fields = fbm(u, v, cells: 3, octaves: 2, salt: 7)
        let clover = smoothstep(0.66, 0.80, noise(u, v, cellsX: 34, cellsY: 34, salt: 8))
        let mottle = fbm(u, v, cells: 14, octaves: 2, salt: 9)
        let k = 0.84 + 0.09 * fields + 0.05 * (mottle - 0.5)
        let base = scale((0.95, 1.0, 0.91), k)
        return mix(base, (0.93, 1.0, 0.82), clover * 0.22)
    }

    /// Cobbles: 5 × 5 rounded stones, each its own pale tone, set in soft mortar.
    public func stone(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let cells = 5
        let edge = roundedCell(u, v, cells: cells)
        let stoneMask = 1 - smoothstep(0.80, 0.98, edge)
        let tone = 0.80 + 0.16 * hash(cell(u * Double(cells), cells), cell(v * Double(cells), cells), 3)
        let grain = 1 + 0.06 * (fbm(u, v, cells: 20, octaves: 2) - 0.5)
        let k = lerp(0.70, tone * grain, stoneMask)
        return (1.0 * k, 0.99 * k, 0.97 * k)
    }

    /// Six planks (seams along u) with gentle grain lines running along each plank.
    public func wood(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let planks = 6
        let fv = fract(v * Double(planks))
        let seam = 1 - smoothstep(0.0, 0.05, min(fv, 1 - fv))
        let plankShift = hash(0, cell(v * Double(planks), planks), 11)
        let wobble = fbm(u, v, cells: 3, octaves: 2) * 3.0
        let grain = 0.5 + 0.5 * sin((v * 24 + wobble + plankShift * 7) * 2 * .pi)
        let plank = 0.86 + 0.06 * grain + 0.05 * (fbm(u, v, cells: 24, octaves: 2) - 0.5)
        let tone = lerp(plank, 0.66, seam)
        return (1.0 * tone, 0.91 * tone, 0.80 * tone)
    }

    /// Brushed metal: soft vertical streaks over a faint mottle.
    public func metal(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let streaks = noise(u, v, cellsX: 3, cellsY: 120, salt: 5)
        let tone = 0.90 + 0.10 * (streaks - 0.5) + 0.04 * (fbm(u, v, cells: 10, octaves: 2) - 0.5)
        return (0.97 * tone, 0.98 * tone, 1.0 * tone)
    }

    /// Felt pile: broad soft mottle with a faint fine nap.
    public func carpet(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let tone = 0.90 + 0.14 * (fbm(u, v, cells: 10, octaves: 3) - 0.5) + 0.04 * (fbm(u, v, cells: 40, octaves: 2, salt: 12) - 0.5)
        return (1.0 * tone, 0.97 * tone, 0.97 * tone)
    }

    /// 8 × 8 checker of satin tiles with pale grout and rounded corners.
    public func labTile(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let tiles = 8
        let iu = cell(u * Double(tiles), tiles)
        let iv = cell(v * Double(tiles), tiles)
        let tileMask = 1 - smoothstep(0.86, 0.98, roundedCell(u, v, cells: tiles))
        let checker = (iu + iv) % 2 == 0 ? 1.0 : 0.93
        let tone = lerp(0.82, checker + 0.03 * (fbm(u, v, cells: 32, octaves: 2) - 0.5), tileMask)
        return (0.98 * tone, 1.0 * tone, 1.0 * tone)
    }

    /// Sand with ten soft wind ripples per tile and a fine grain.
    public func sand(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let ripples = 0.5 + 0.5 * sin((v * 10 + fbm(u, v, cells: 4, octaves: 2) * 2) * 2 * .pi)
        let tone = 0.90 + 0.12 * (fbm(u, v, cells: 16, octaves: 3) - 0.5) + 0.05 * (ripples - 0.5)
        return (1.0 * tone, 0.96 * tone, 0.86 * tone)
    }

    /// Fur: 120 soft strands per tile along u, clumped. Dark on purpose (the tint keeps the kitten black) with
    /// enough range that the strands catch the rim light.
    public func fur(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let strands = noise(u, v, cellsX: 120, cellsY: 9, salt: 21)
        let clumps = fbm(u, v, cells: 8, octaves: 2, salt: 22)
        let tone = 0.62 + 0.24 * strands + 0.14 * clumps
        return (tone * 0.96, tone * 0.96, tone * 1.0)
    }

    /// Tree bark: soft vertical ridges with mottling.
    public func bark(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let ridges = noise(u, v, cellsX: 24, cellsY: 5, salt: 41)
        let mottle = fbm(u, v, cells: 8, octaves: 3, salt: 42)
        let tone = 0.70 + 0.24 * ridges + 0.12 * (mottle - 0.5)
        return (1.0 * tone, 0.93 * tone, 0.85 * tone)
    }

    /// Foliage: soft overlapping leaf clusters, lighter where they catch the light, with broad shading.
    public func leaves(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let big = noise(u, v, cellsX: 14, cellsY: 14, salt: 51)
        let small = noise(u + 0.5, v + 0.5, cellsX: 28, cellsY: 28, salt: 53)
        let clusters = smoothstep(0.30, 0.75, 0.6 * big + 0.4 * small)
        let shade = fbm(u, v, cells: 4, octaves: 2, salt: 52)
        let tone = 0.74 + 0.20 * clusters + 0.10 * (shade - 0.5)
        return (0.94 * tone, 1.0 * tone, 0.90 * tone)
    }

    /// Woven wicker: 12 × 12 cells, alternating which strand lies on top, softly lit.
    public func wicker(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let strands = 12
        let along = 0.5 + 0.5 * sin(u * Double(strands) * 2 * .pi)
        let across = 0.5 + 0.5 * sin(v * Double(strands) * 2 * .pi)
        let parity = (cell(u * Double(strands), strands) + cell(v * Double(strands), strands)) % 2
        let weave = parity == 0 ? along : across
        let tone = 0.74 + 0.22 * weave + 0.04 * (fbm(u, v, cells: 12, octaves: 2, salt: 61) - 0.5)
        return (1.0 * tone, 0.96 * tone, 0.90 * tone)
    }

    /// Fruit peel: soft pale spots (the tops of the peel's bumps) over a faint mottle, glossy in the material.
    public func fruit(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let pores = noise(u, v, cellsX: 18, cellsY: 18, salt: 71)
        let spots = smoothstep(0.55, 0.85, pores)
        let mottle = fbm(u, v, cells: 5, octaves: 2, salt: 72)
        let tone = 0.88 + 0.08 * spots + 0.06 * (mottle - 0.5)
        return (1.0 * tone, 0.98 * tone, 0.95 * tone)
    }

    /// Soft contact shadow: opaque in the middle, fading to nothing at the edge of the disc: 1 − smoothstep.
    public func blob(_ u: Double, _ v: Double) -> Double {
        let dx = u - 0.5
        let dy = v - 0.5
        let d = (dx * dx + dy * dy).squareRoot() * 2
        return 1 - smoothstep(0.25, 1.0, d)
    }

    // MARK: Heights (for normal maps) — gentle relief: rolling bumps and rounded edges, nothing sharp

    public func grassHeight(_ u: Double, _ v: Double) -> Double {
        let clover = smoothstep(0.66, 0.80, noise(u, v, cellsX: 34, cellsY: 34, salt: 8))
        return 0.7 * fbm(u, v, cells: 6, octaves: 3, salt: 31) + 0.3 * clover
    }

    public func stoneHeight(_ u: Double, _ v: Double) -> Double {
        let dome = 1 - smoothstep(0.62, 1.0, roundedCell(u, v, cells: 5))
        return 0.85 * dome + 0.15 * fbm(u, v, cells: 20, octaves: 2, salt: 32)
    }

    public func woodHeight(_ u: Double, _ v: Double) -> Double {
        let planks = 6.0
        let fv = fract(v * planks)
        let plankBevel = smoothstep(0.0, 0.08, min(fv, 1 - fv))
        let grain = 0.5 + 0.5 * sin((v * 24 + fbm(u, v, cells: 3, octaves: 2) * 3.0) * 2 * .pi)
        return 0.85 * plankBevel + 0.15 * grain
    }

    public func furHeight(_ u: Double, _ v: Double) -> Double {
        noise(u, v, cellsX: 120, cellsY: 9, salt: 21)
    }

    public func fruitHeight(_ u: Double, _ v: Double) -> Double {
        0.5 + 0.5 * smoothstep(0.55, 0.85, noise(u, v, cellsX: 18, cellsY: 18, salt: 71))
    }

    public func barkHeight(_ u: Double, _ v: Double) -> Double {
        0.7 * noise(u, v, cellsX: 24, cellsY: 5, salt: 41) + 0.3 * fbm(u, v, cells: 8, octaves: 3, salt: 42)
    }
}
