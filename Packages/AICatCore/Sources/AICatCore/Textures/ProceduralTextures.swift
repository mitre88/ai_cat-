import Foundation

/// The procedural textures of the worlds. Every surface is a formula over tileable value noise, so no image
/// ships with the app and each world still has grain, grass and grit. The formulas live here (Foundation only)
/// so `swift test` checks tileability, ranges and normal-map geometry; the app wraps the pixels in a CGImage.
///
/// Colour textures are *structure*, not colour: their mean brightness is close to 1 with a faint hue, and the
/// material's tint (the world palette) multiplies them, so each world keeps its colour identity.
public enum TextureKind: String, CaseIterable, Sendable {
    // colour (premultiplied RGBA, opaque)
    case grass, stone, wood, metal, carpet, labTile, sand, fur, bark, leaves, wicker
    // alpha only (black with a radial falloff)
    case blobShadow
    // tangent-space normal maps
    case grassNormal, stoneNormal, woodNormal, furNormal, barkNormal

    public var isNormalMap: Bool { rawValue.hasSuffix("Normal") }

    /// Pixels per side. Grounds and the coat fill the screen; props are small, the shadow is a smooth gradient.
    public var preferredSize: Int {
        switch self {
        case .bark, .barkNormal, .leaves, .wicker: return 256
        case .blobShadow: return 128
        default: return 512
        }
    }

    /// A stable seed per kind (`hashValue` changes every launch; textures must not).
    public var seed: UInt32 {
        UInt32(TextureKind.allCases.firstIndex(of: self) ?? 0) &* 7919 &+ 13
    }
}

/// Row-major, premultiplied RGBA8 pixels of a square image.
public struct RGBAImage: Equatable, Sendable {
    public let size: Int
    public let pixels: [UInt8]

    public init(size: Int, pixels: [UInt8]) {
        self.size = size
        self.pixels = pixels
    }

    /// The four channels of pixel (x, y).
    public func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * size + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }
}

public enum ProceduralTextures {
    public typealias RGB = (r: Double, g: Double, b: Double)

    /// Normal-map strength (height gradient multiplier) per kind; larger = deeper relief.
    static func normalStrength(_ kind: TextureKind) -> Double {
        switch kind {
        case .stoneNormal: return 2.2
        case .grassNormal: return 1.6
        case .woodNormal: return 1.4
        case .barkNormal: return 1.8
        default: return 1.0
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
        return RGBAImage(size: size, pixels: pixels)
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

    /// Black with the alpha the closure returns (premultiplied, so the colour channels stay 0).
    private static func paintAlpha(_ pixels: inout [UInt8], _ size: Int, _ alpha: (Double, Double) -> Double) {
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                pixels[index] = 0
                pixels[index + 1] = 0
                pixels[index + 2] = 0
                pixels[index + 3] = byte(alpha(Double(x) / Double(size), Double(y) / Double(size)))
            }
        }
    }

    /// Tangent-space normal map from a tileable height field: n = normalize(−∂h/∂x·s, −∂h/∂y·s, 1),
    /// encoded as (n + 1) / 2. Central differences wrap around, so the map tiles like the height field.
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
                let ny = -dy * strength / 64
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
        case .blobShadow, .grassNormal, .stoneNormal, .woodNormal, .furNormal, .barkNormal:
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
        default: return 0.5
        }
    }

    // MARK: Surfaces (colour) — mean brightness near 1, faint hue; the palette tint supplies the colour

    /// Patches of darker and lighter grass, fine blades and a few pale specks.
    public func grass(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let patches = fbm(u, v, cells: 6, octaves: 4)
        let blades = noise(u, v, cellsX: 96, cellsY: 14, salt: 7)
        let speck = hash(cell(u * Double(size), size), cell(v * Double(size), size), 99) > 0.985
        let k = 0.70 + 0.40 * patches + 0.20 * (blades - 0.5)
        return mix(scale((0.94, 1.0, 0.86), k), (1.0, 1.0, 0.80), speck ? 0.5 : 0)
    }

    /// Flagstones: 4 × 4 slabs, each a slightly different tone, mortar in between.
    public func stone(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let tiles = 4
        let fu = fract(u * Double(tiles))
        let fv = fract(v * Double(tiles))
        let mortar = fu < 0.05 || fu > 0.95 || fv < 0.05 || fv > 0.95
        let slabTone = 0.82 + 0.20 * hash(cell(u * Double(tiles), tiles), cell(v * Double(tiles), tiles), 3)
        let grain = 0.92 + 0.16 * fbm(u, v, cells: 24, octaves: 3)
        let tone = mortar ? 0.55 : slabTone * grain
        return (1.0 * tone, 0.99 * tone, 0.97 * tone)
    }

    /// Six planks with wavy grain `sin(22u + fBm)` and dark seams.
    public func wood(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let planks = 6
        let fv = fract(v * Double(planks))
        let seam = fv < 0.035 || fv > 0.965
        let plankShift = hash(0, cell(v * Double(planks), planks), 11)
        let wobble = fbm(u, v, cells: 3, octaves: 2) * 4
        let grain = 0.5 + 0.5 * sin((u * 22 + wobble + plankShift * 7) * 2 * .pi)
        let tone = seam ? 0.50 : 0.84 + 0.14 * grain + 0.08 * (fbm(u, v, cells: 48, octaves: 2) - 0.5)
        return (1.0 * tone, 0.90 * tone, 0.78 * tone)
    }

    /// Brushed metal: long vertical streaks over a faint mottle.
    public func metal(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let streaks = noise(u, v, cellsX: 3, cellsY: 160, salt: 5)
        let tone = 0.90 + 0.18 * (streaks - 0.5) + 0.06 * (fbm(u, v, cells: 12, octaves: 2) - 0.5)
        return (0.97 * tone, 0.98 * tone, 1.0 * tone)
    }

    /// Velvet-like pile: fine, soft mottle.
    public func carpet(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let tone = 0.90 + 0.30 * (fbm(u, v, cells: 64, octaves: 2) - 0.5)
        return (1.0 * tone, 0.97 * tone, 0.97 * tone)
    }

    /// 8 × 8 checker of glossy tiles with light grout.
    public func labTile(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let tiles = 8
        let iu = cell(u * Double(tiles), tiles)
        let iv = cell(v * Double(tiles), tiles)
        let fu = fract(u * Double(tiles))
        let fv = fract(v * Double(tiles))
        let grout = fu < 0.04 || fu > 0.96 || fv < 0.04 || fv > 0.96
        let checker = (iu + iv) % 2 == 0 ? 1.0 : 0.90
        let tone = grout ? 0.74 : checker + 0.04 * (fbm(u, v, cells: 32, octaves: 2) - 0.5)
        return (0.98 * tone, 1.0 * tone, 1.0 * tone)
    }

    /// Sand with 14 wind ripples per tile and fine grain.
    public func sand(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let ripples = 0.5 + 0.5 * sin((v * 14 + fbm(u, v, cells: 4, octaves: 2) * 3) * 2 * .pi)
        let tone = 0.90 + 0.18 * (fbm(u, v, cells: 24, octaves: 3) - 0.5) + 0.08 * (ripples - 0.5)
        return (1.0 * tone, 0.96 * tone, 0.86 * tone)
    }

    /// Fur: 180 strands per tile along u, clumped. Dark on purpose (the tint keeps the kitten black) but with
    /// enough range that the strands read under the rim light.
    public func fur(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let strands = noise(u, v, cellsX: 180, cellsY: 9, salt: 21)
        let clumps = fbm(u, v, cells: 8, octaves: 2, salt: 22)
        let tone = 0.55 + 0.30 * strands + 0.15 * clumps
        return (tone * 0.96, tone * 0.96, tone * 1.0)
    }

    /// Tree bark: deep vertical ridges with mottling.
    public func bark(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let ridges = noise(u, v, cellsX: 40, cellsY: 5, salt: 41)
        let mottle = fbm(u, v, cells: 10, octaves: 3, salt: 42)
        let tone = 0.58 + 0.34 * ridges + 0.16 * (mottle - 0.5)
        return (1.0 * tone, 0.93 * tone, 0.85 * tone)
    }

    /// Foliage: overlapping leaf-sized blobs, lit from above (the top of each blob is lighter).
    public func leaves(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let blobs = noise(u, v, cellsX: 28, cellsY: 28, salt: 51)
        let shade = fbm(u, v, cells: 5, octaves: 3, salt: 52)
        let edge = smoothstep(0.35, 0.75, blobs)
        let tone = 0.62 + 0.36 * edge + 0.16 * (shade - 0.5)
        return mix((0.95 * tone, 1.0 * tone, 0.90 * tone), (1.0, 1.0, 0.82), edge > 0.95 ? 0.35 : 0)
    }

    /// Woven wicker: 16 × 16 cells, alternating which strand lies on top.
    public func wicker(_ u: Double, _ v: Double) -> ProceduralTextures.RGB {
        let strands = 16
        let along = 0.5 + 0.5 * sin(u * Double(strands) * 2 * .pi)
        let across = 0.5 + 0.5 * sin(v * Double(strands) * 2 * .pi)
        let parity = (cell(u * Double(strands), strands) + cell(v * Double(strands), strands)) % 2
        let weave = parity == 0 ? along : across
        let tone = 0.62 + 0.36 * weave + 0.08 * (fbm(u, v, cells: 12, octaves: 2, salt: 61) - 0.5)
        return (1.0 * tone, 0.96 * tone, 0.90 * tone)
    }

    /// Soft contact shadow: opaque in the middle, fading to nothing at the edge of the disc: 1 − smoothstep.
    public func blob(_ u: Double, _ v: Double) -> Double {
        let dx = u - 0.5
        let dy = v - 0.5
        let d = (dx * dx + dy * dy).squareRoot() * 2
        return 1 - smoothstep(0.25, 1.0, d)
    }

    // MARK: Heights (for normal maps)

    public func grassHeight(_ u: Double, _ v: Double) -> Double {
        0.6 * fbm(u, v, cells: 20, octaves: 3, salt: 31) + 0.4 * noise(u, v, cellsX: 96, cellsY: 14, salt: 7)
    }

    public func stoneHeight(_ u: Double, _ v: Double) -> Double {
        let tiles = 4.0
        let fu = fract(u * tiles)
        let fv = fract(v * tiles)
        let edge = min(min(fu, 1 - fu), min(fv, 1 - fv))
        let bevel = clamp01(edge / 0.08)
        return 0.75 * bevel + 0.25 * fbm(u, v, cells: 24, octaves: 3, salt: 32)
    }

    public func woodHeight(_ u: Double, _ v: Double) -> Double {
        let planks = 6.0
        let fv = fract(v * planks)
        let seam = min(fv, 1 - fv)
        let plankBevel = clamp01(seam / 0.05)
        let grain = 0.5 + 0.5 * sin((u * 22 + fbm(u, v, cells: 3, octaves: 2) * 4) * 2 * .pi)
        return 0.8 * plankBevel + 0.2 * grain
    }

    public func furHeight(_ u: Double, _ v: Double) -> Double {
        noise(u, v, cellsX: 180, cellsY: 9, salt: 21)
    }

    public func barkHeight(_ u: Double, _ v: Double) -> Double {
        0.7 * noise(u, v, cellsX: 40, cellsY: 5, salt: 41) + 0.3 * fbm(u, v, cells: 10, octaves: 3, salt: 42)
    }
}
