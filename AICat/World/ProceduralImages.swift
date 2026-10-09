import CoreGraphics
import Foundation
import AICatCore

/// Wraps the pixels computed by AICatCore (`ProceduralTextures`, `ProceduralSky`; both unit-tested) in a
/// CGImage for RealityKit. Pure (no actor), safe to run on a background task.
enum ProceduralImages {
    static func image(for kind: TextureKind, size: Int? = nil) -> CGImage? {
        cgImage(ProceduralTextures.render(kind, size: size))
    }

    /// Premultiplied RGBA8 pixels → CGImage (the bytes are copied once into the data provider).
    static func cgImage(_ image: RGBAImage) -> CGImage? {
        let data = Data(image.pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: image.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
