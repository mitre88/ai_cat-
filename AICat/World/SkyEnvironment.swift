import RealityKit
import CoreGraphics
import SwiftUI
import UIKit
import AICatCore

/// Procedural equirectangular sky (a vertical gradient) used both as the skybox and as the image-based light.
enum SkyEnvironment {
    static func image(for theme: WorldTheme, width: Int = 512, height: Int = 256) -> CGImage? {
        let palette = Theme.palette(for: theme)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let top = UIColor(palette.sky).cgColor
        let horizon = UIColor.white.cgColor
        let ground = UIColor(palette.ground).cgColor
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, horizon, ground] as CFArray, locations: [0, 0.5, 1]) else { return nil }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: 0, y: 0), options: [])
        return context.makeImage()
    }

    /// nil when the resource cannot be created (the SwiftUI gradient stays as the sky).
    @MainActor
    static func resource(for theme: WorldTheme) async -> EnvironmentResource? {
        guard let image = image(for: theme) else { return nil }
        return try? await EnvironmentResource(equirectangular: image, withName: "sky-\(theme.rawValue)")
    }
}
