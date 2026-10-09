import RealityKit
import CoreGraphics
import SwiftUI
import UIKit
import AICatCore

/// Procedural equirectangular sky computed by `ProceduralSky` (AICatCore, unit-tested): a zenith–horizon–ground
/// gradient in the world's palette, a sun whose position matches the directional light, and fBm clouds.
/// Used both as the skybox and as the image-based light, so the ambient light has a direction.
enum SkyEnvironment {
    static func image(for theme: WorldTheme, width: Int = 512, height: Int = 256) -> CGImage? {
        let palette = Theme.palette(for: theme)
        let colors = SkyColors(top: rgb(palette.sky), horizon: (1, 1, 1), ground: rgb(palette.ground))
        return ProceduralImages.cgImage(ProceduralSky.render(colors, width: width, height: height))
    }

    /// sRGB components of a palette colour.
    static func rgb(_ color: Color) -> ProceduralTextures.RGB {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        _ = UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    @MainActor private static var cache: [WorldTheme: EnvironmentResource] = [:]
    @MainActor private static var loads: [WorldTheme: Task<EnvironmentResource?, Never>] = [:]

    /// The sky of a theme, rendered once per launch (pixels off the main thread, then the environment's
    /// prefiltering) and shared by every world of that theme; nil when the resource cannot be created
    /// (the SwiftUI gradient stays as the sky).
    @MainActor
    static func resource(for theme: WorldTheme) async -> EnvironmentResource? {
        if let cached = cache[theme] { return cached }
        let load: Task<EnvironmentResource?, Never>
        if let running = loads[theme] {
            load = running
        } else {
            load = Task<EnvironmentResource?, Never> { @MainActor in
                let image = await Task.detached(priority: .userInitiated) { SkyEnvironment.image(for: theme) }.value
                guard let image else { return nil }
                return try? await EnvironmentResource(equirectangular: image, withName: "sky-\(theme.rawValue)")
            }
            loads[theme] = load
        }
        let resource = await load.value
        if let resource {
            cache[theme] = resource
        }
        if loads[theme] == load {
            loads[theme] = nil
        }
        return resource
    }
}
