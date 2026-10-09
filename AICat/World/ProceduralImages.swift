import CoreGraphics
import Foundation

/// Procedural, tileable textures generated on the device from seeded value noise. No image assets ship:
/// every surface is a small formula, so the app stays tiny and every world still has grain, grass and grit.
/// Pure functions (no actor), safe to run on a background task.
enum ProceduralImages {
    static func image(for kind: TextureKind, size: Int = 512) -> CGImage? {
        let field = NoiseField(size: size, seed: UInt32(truncatingIfNeeded: kind.rawValue.hashValue) | 1)
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        switch kind {
        case .grass: paintColor(&pixels, size) { field.grass($0, $1) }
        case .stone: paintColor(&pixels, size) { field.stone($0, $1) }
        case .wood: paintColor(&pixels, size) { field.wood($0, $1) }
        case .metal: paintColor(&pixels, size) { field.metal($0, $1) }
        case .carpet: paintColor(&pixels, size) { field.carpet($0, $1) }
        case .labTile: paintColor(&pixels, size) { field.labTile($0, $1) }
        case .sand: paintColor(&pixels, size) { field.sand($0, $1) }
        case .fur: paintColor(&pixels, size) { field.fur($0, $1) }
        case .blobShadow: paintAlpha(&pixels, size) { field.blob($0, $1) }
        case .grassNormal: paintNormal(&pixels, size, strength: 1.6) { field.grassHeight($0, $1) }
        case .stoneNormal: paintNormal(&pixels, size, strength: 2.2) { field.stoneHeight($0, $1) }
        case .woodNormal: paintNormal(&pixels, size, strength: 1.4) { field.woodHeight($0, $1) }
        case .furNormal: paintNormal(&pixels, size, strength: 1.0) { field.furHeight($0, $1) }
        }
        return makeImage(pixels, size: size)
    }

    // MARK: Pixel painters

    typealias RGB = (r: Double, g: Double, b: Double)

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

    /// Tangent-space normal map from a tileable height field: n = normalize(−∂h/∂x·s, −∂h/∂y·s, 1).
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
                var nx = -dx * strength / 64
                var ny = -dy * strength / 64
                let nz = 1.0
                let length = (nx * nx + ny * ny + nz * nz).squareRoot()
                nx /= length
                ny /= length
                let index = (y * size + x) * 4
                pixels[index] = byte(nx * 0.5 + 0.5)
                pixels[index + 1] = byte(ny * 0.5 + 0.5)
                pixels[index + 2] = byte(nz / length * 0.5 + 0.5)
                pixels[index + 3] = 255
            }
        }
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }

    private static func makeImage(_ pixels: [UInt8], size: Int) -> CGImage? {
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// Tileable value noise on a lattice of `cells` × `cells` (wrapping), plus the surface formulas.
struct NoiseField {
    let size: Int
    let seed: UInt32

    // MARK: Noise

    private func hash(_ x: Int, _ y: Int, _ salt: UInt32) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 374_761_393 &+ UInt32(truncatingIfNeeded: y) &* 668_265_263 &+ seed &* 2_246_822_519 &+ salt &* 3_266_489_917
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFFFF) / Double(0x1000000)
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    /// Value noise in [0, 1] that tiles every 1.0 in u and v for any integer `cells`.
    func noise(_ u: Double, _ v: Double, cellsX: Int, cellsY: Int, salt: UInt32 = 0) -> Double {
        let px = u * Double(cellsX)
        let py = v * Double(cellsY)
        let ix = Int(px.rounded(.down))
        let iy = Int(py.rounded(.down))
        let fx = smooth(px - Double(ix))
        let fy = smooth(py - Double(iy))
        func corner(_ cx: Int, _ cy: Int) -> Double {
            hash(((cx % cellsX) + cellsX) % cellsX, ((cy % cellsY) + cellsY) % cellsY, salt)
        }
        let top = corner(ix, iy) + (corner(ix + 1, iy) - corner(ix, iy)) * fx
        let bottom = corner(ix, iy + 1) + (corner(ix + 1, iy + 1) - corner(ix, iy + 1)) * fx
        return top + (bottom - top) * fy
    }

    /// Fractal sum of `octaves` noises, each twice as fine; stays in [0, 1].
    func fbm(_ u: Double, _ v: Double, cells: Int, octaves: Int, salt: UInt32 = 0) -> Double {
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

    private func mix(_ a: ProceduralImages.RGB, _ b: ProceduralImages.RGB, _ t: Double) -> ProceduralImages.RGB {
        (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    private func scale(_ c: ProceduralImages.RGB, _ k: Double) -> ProceduralImages.RGB { (c.r * k, c.g * k, c.b * k) }

    // MARK: Surfaces (colour)

    func grass(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let base: ProceduralImages.RGB = (0.46, 0.68, 0.32)
        let patches = fbm(u, v, cells: 6, octaves: 4)
        let blades = noise(u, v, cellsX: 96, cellsY: 14, salt: 7)
        let speck = hash(Int(u * Double(size)), Int(v * Double(size)), 99) > 0.985 ? 0.12 : 0
        let k = 0.72 + 0.38 * patches + 0.18 * (blades - 0.5) + speck
        return mix(scale(base, k), (0.72, 0.80, 0.40), speck > 0 ? 0.5 : 0)
    }

    func stone(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let tiles = 4.0
        let fu = u * tiles - (u * tiles).rounded(.down)
        let fv = v * tiles - (v * tiles).rounded(.down)
        let mortar = fu < 0.05 || fu > 0.95 || fv < 0.05 || fv > 0.95
        let cellTone = 0.78 + 0.22 * hash(Int(u * tiles), Int(v * tiles), 3)
        let grain = 0.9 + 0.2 * fbm(u, v, cells: 24, octaves: 3)
        let tone = mortar ? 0.42 : cellTone * grain
        return (0.70 * tone, 0.69 * tone, 0.66 * tone)
    }

    func wood(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let planks = 6.0
        let fv = v * planks - (v * planks).rounded(.down)
        let seam = fv < 0.035 || fv > 0.965
        let plankShift = hash(0, Int(v * planks), 11)
        let wobble = fbm(u, v, cells: 3, octaves: 2) * 4
        let grain = 0.5 + 0.5 * sin((u * 22 + wobble + plankShift * 7) * 2 * .pi)
        let tone = seam ? 0.45 : 0.80 + 0.14 * grain + 0.08 * (fbm(u, v, cells: 48, octaves: 2) - 0.5)
        return (0.64 * tone, 0.47 * tone, 0.31 * tone)
    }

    func metal(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let streaks = noise(u, v, cellsX: 3, cellsY: 160, salt: 5)
        let tone = 0.82 + 0.22 * (streaks - 0.5) + 0.06 * (fbm(u, v, cells: 12, octaves: 2) - 0.5)
        return (0.60 * tone, 0.62 * tone, 0.67 * tone)
    }

    func carpet(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let tone = 0.82 + 0.36 * (fbm(u, v, cells: 64, octaves: 2) - 0.5)
        return (0.62 * tone, 0.20 * tone, 0.26 * tone)
    }

    func labTile(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let tiles = 8.0
        let iu = Int(u * tiles)
        let iv = Int(v * tiles)
        let fu = u * tiles - Double(iu)
        let fv = v * tiles - Double(iv)
        let grout = fu < 0.04 || fu > 0.96 || fv < 0.04 || fv > 0.96
        let checker = (iu + iv) % 2 == 0 ? 0.95 : 0.86
        let tone = grout ? 0.70 : checker + 0.04 * (fbm(u, v, cells: 32, octaves: 2) - 0.5)
        return (0.90 * tone, 0.93 * tone, 0.95 * tone)
    }

    func sand(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let ripples = 0.5 + 0.5 * sin((v * 14 + fbm(u, v, cells: 4, octaves: 2) * 3) * 2 * .pi)
        let tone = 0.84 + 0.22 * (fbm(u, v, cells: 24, octaves: 3) - 0.5) + 0.08 * (ripples - 0.5)
        return (0.82 * tone, 0.73 * tone, 0.52 * tone)
    }

    func fur(_ u: Double, _ v: Double) -> ProceduralImages.RGB {
        let strands = noise(u, v, cellsX: 180, cellsY: 9, salt: 21)
        let clumps = fbm(u, v, cells: 8, octaves: 2, salt: 22)
        let tone = 0.045 + 0.09 * strands + 0.05 * clumps
        return (tone * 0.95, tone * 0.95, tone * 1.15)
    }

    /// Soft contact shadow: opaque in the middle, fading to nothing at the edge of the disc.
    func blob(_ u: Double, _ v: Double) -> Double {
        let dx = u - 0.5
        let dy = v - 0.5
        let d = (dx * dx + dy * dy).squareRoot() * 2
        let t = max(0, min(1, (d - 0.25) / 0.75))
        return 1 - t * t * (3 - 2 * t)
    }

    // MARK: Heights (for normal maps)

    func grassHeight(_ u: Double, _ v: Double) -> Double {
        0.6 * fbm(u, v, cells: 20, octaves: 3, salt: 31) + 0.4 * noise(u, v, cellsX: 96, cellsY: 14, salt: 7)
    }

    func stoneHeight(_ u: Double, _ v: Double) -> Double {
        let tiles = 4.0
        let fu = u * tiles - (u * tiles).rounded(.down)
        let fv = v * tiles - (v * tiles).rounded(.down)
        let edge = min(min(fu, 1 - fu), min(fv, 1 - fv))
        let bevel = max(0, min(1, edge / 0.08))
        return 0.75 * bevel + 0.25 * fbm(u, v, cells: 24, octaves: 3, salt: 32)
    }

    func woodHeight(_ u: Double, _ v: Double) -> Double {
        let planks = 6.0
        let fv = v * planks - (v * planks).rounded(.down)
        let seam = min(fv, 1 - fv)
        let plankBevel = max(0, min(1, seam / 0.05))
        let grain = 0.5 + 0.5 * sin((u * 22 + fbm(u, v, cells: 3, octaves: 2) * 4) * 2 * .pi)
        return 0.8 * plankBevel + 0.2 * grain
    }

    func furHeight(_ u: Double, _ v: Double) -> Double {
        noise(u, v, cellsX: 180, cellsY: 9, salt: 21)
    }
}
