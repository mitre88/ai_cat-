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
        // Sun: a warm radial glow high on one side, so the image-based light has a direction.
        let sunCenter = CGPoint(x: CGFloat(width) * 0.68, y: CGFloat(height) * 0.74)
        let sunColors = [UIColor(red: 1, green: 0.97, blue: 0.86, alpha: 1).cgColor, UIColor(red: 1, green: 0.95, blue: 0.80, alpha: 0).cgColor]
        if let sun = CGGradient(colorsSpace: colorSpace, colors: sunColors as CFArray, locations: [0, 1]) {
            context.drawRadialGradient(sun, startCenter: sunCenter, startRadius: 0, endCenter: sunCenter, endRadius: CGFloat(width) * 0.10, options: [])
        }
        // Clouds: a few soft, translucent ellipses in the upper half.
        context.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
        let clouds: [(Double, Double, Double, Double)] = [(0.12, 0.66, 0.16, 0.05), (0.20, 0.63, 0.10, 0.04), (0.45, 0.70, 0.18, 0.05),
                                                           (0.52, 0.67, 0.12, 0.04), (0.82, 0.62, 0.14, 0.045), (0.88, 0.60, 0.09, 0.035)]
        for (cx, cy, rx, ry) in clouds {
            let rect = CGRect(x: CGFloat(cx - rx) * CGFloat(width), y: CGFloat(cy - ry) * CGFloat(height), width: CGFloat(rx * 2) * CGFloat(width), height: CGFloat(ry * 2) * CGFloat(height))
            context.fillEllipse(in: rect)
        }
        return context.makeImage()
    }

    /// nil when the resource cannot be created (the SwiftUI gradient stays as the sky).
    @MainActor
    static func resource(for theme: WorldTheme) async -> EnvironmentResource? {
        guard let image = image(for: theme) else { return nil }
        return try? await EnvironmentResource(equirectangular: image, withName: "sky-\(theme.rawValue)")
    }
}
