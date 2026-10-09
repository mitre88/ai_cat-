import Foundation

/// The three bands of a world's sky, as linear-ish RGB in [0, 1].
public struct SkyColors: Equatable, Sendable {
    public var top: ProceduralTextures.RGB
    public var horizon: ProceduralTextures.RGB
    public var ground: ProceduralTextures.RGB

    public init(top: ProceduralTextures.RGB, horizon: ProceduralTextures.RGB, ground: ProceduralTextures.RGB) {
        self.top = top
        self.horizon = horizon
        self.ground = ground
    }

    public static func == (lhs: SkyColors, rhs: SkyColors) -> Bool {
        lhs.top == rhs.top && lhs.horizon == rhs.horizon && lhs.ground == rhs.ground
    }
}

/// Procedural equirectangular sky: a vertical gradient (zenith → horizon → ground), a sun with a warm glow
/// and fBm clouds that fade at the horizon. Used as the skybox and as the image-based light, so the sun's
/// position gives the ambient light a direction. Row 0 is the zenith, the middle row the horizon.
/// Periodic in u (the seam at the back of the sky is invisible).
public enum ProceduralSky {
    /// Where the sun sits in the image (u across, v down); its elevation matches the directional light.
    public static let sunU = 0.68
    public static let sunV = 0.26

    public static func render(_ colors: SkyColors, width: Int = 512, height: Int = 256, seed: UInt32 = 5) -> RGBAImage {
        let width = max(4, width)
        let height = max(4, height)
        let field = NoiseField(size: width, seed: seed)
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = color(colors, u: Double(x) / Double(width), v: Double(y) / Double(height), field: field)
                let index = (y * width + x) * 4
                pixels[index] = ProceduralTextures.byte(c.r)
                pixels[index + 1] = ProceduralTextures.byte(c.g)
                pixels[index + 2] = ProceduralTextures.byte(c.b)
                pixels[index + 3] = 255
            }
        }
        return RGBAImage(width: width, height: height, pixels: pixels)
    }

    /// Final colour at (u, v): gradient, then clouds, then the sun on top (it must stay visible for the light).
    public static func color(_ colors: SkyColors, u: Double, v: Double, field: NoiseField) -> ProceduralTextures.RGB {
        var c = gradient(colors, v)
        let clouds = cloudDensity(u: u, v: v, field: field)
        if clouds > 0 {
            let detail = field.fbm(u, v * 2, cells: 24, octaves: 2, salt: 82)
            let shade = 0.84 + 0.16 * detail
            c = mix(c, (shade, shade, shade), clouds * 0.9)
        }
        let sun = sunlight(u: u, v: v)
        c.r = min(1, c.r + sun.disc * 1.0 + sun.glow * 0.60)
        c.g = min(1, c.g + sun.disc * 0.98 + sun.glow * 0.52)
        c.b = min(1, c.b + sun.disc * 0.90 + sun.glow * 0.36)
        return c
    }

    /// Zenith (v = 0) → horizon (v = 0.5) → ground (v = 1); the lower half is the ground colour slightly
    /// darkened, which is what the image-based light bounces up from below.
    public static func gradient(_ colors: SkyColors, _ v: Double) -> ProceduralTextures.RGB {
        if v <= 0.5 {
            let t = pow(max(0, min(1, (0.5 - v) / 0.5)), 0.8)
            return mix(colors.horizon, colors.top, t)
        }
        let t = pow(max(0, min(1, (v - 0.5) / 0.5)), 0.6)
        let ground = (colors.ground.r * 0.85, colors.ground.g * 0.85, colors.ground.b * 0.85)
        return mix(colors.horizon, ground, t)
    }

    /// Cloud cover in [0, 1]: fBm thresholded softly, fading out just above the horizon and absent below it.
    public static func cloudDensity(u: Double, v: Double, field: NoiseField) -> Double {
        let elevation = 0.5 - v
        guard elevation > 0.01 else { return 0 }
        let cover = field.fbm(u, v * 2, cells: 6, octaves: 4, salt: 81)
        return smoothstep(0.50, 0.68, cover) * smoothstep(0.01, 0.12, elevation)
    }

    /// Sun disc (hard edge) and glow (Gaussian in angle) at (u, v), from the angle between that direction
    /// and the sun's on the sphere: the disc is round wherever it sits in the equirectangular image.
    public static func sunlight(u: Double, v: Double) -> (disc: Double, glow: Double) {
        let angle = angleToSun(u: u, v: v)
        let disc = 1 - smoothstep(0.075, 0.10, angle)   // ≈ 5° radius: a cartoon sun, big enough to read in the IBL
        let glow = 0.5 * exp(-(angle / 0.30) * (angle / 0.30))
        return (disc, glow)
    }

    /// Angle (radians) between the direction of pixel (u, v) and the sun's direction.
    public static func angleToSun(u: Double, v: Double) -> Double {
        let a = direction(u: u, v: v)
        let s = direction(u: sunU, v: sunV)
        let dot = max(-1, min(1, a.x * s.x + a.y * s.y + a.z * s.z))
        return acos(dot)
    }

    /// Equirectangular (u, v) → unit direction: u is the azimuth (one turn), v the elevation (zenith at 0).
    static func direction(u: Double, v: Double) -> (x: Double, y: Double, z: Double) {
        let theta = u * 2 * Double.pi
        let epsilon = (0.5 - v) * Double.pi
        return (cos(epsilon) * sin(theta), sin(epsilon), cos(epsilon) * cos(theta))
    }

    private static func mix(_ a: ProceduralTextures.RGB, _ b: ProceduralTextures.RGB, _ t: Double) -> ProceduralTextures.RGB {
        (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}
