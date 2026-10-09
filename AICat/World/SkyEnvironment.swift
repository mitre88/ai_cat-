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

    /// nil when the resource cannot be created (the SwiftUI gradient stays as the sky). The pixels are
    /// computed off the main thread.
    @MainActor
    static func resource(for theme: WorldTheme) async -> EnvironmentResource? {
        let image = await Task.detached(priority: .userInitiated) { SkyEnvironment.image(for: theme) }.value
        guard let image else { return nil }
        return try? await EnvironmentResource(equirectangular: image, withName: "sky-\(theme.rawValue)")
    }
}
