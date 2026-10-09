import CoreGraphics
import Foundation
import AICatCore

/// Wraps the pure texture formulas of `ProceduralTextures` (AICatCore, unit-tested) in a CGImage for RealityKit.
/// Pure (no actor), safe to run on a background task.
enum ProceduralImages {
    static func image(for kind: TextureKind, size: Int? = nil) -> CGImage? {
        let image = ProceduralTextures.render(kind, size: size)
        let data = Data(image.pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: image.size, height: image.size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: image.size * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
