import Foundation
import CoreGraphics
import ImageIO

// Renders every procedural texture and three skies as PNG files (macOS). Built by Tools/render_textures.sh
// together with the two texture files of AICatCore, so no Xcode project is needed to look at the surfaces.

func write(_ image: RGBAImage, to url: URL) {
    let data = Data(image.pixels)
    guard let provider = CGDataProvider(data: data as CFData),
          let cgImage = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("could not write \(url.path)")
        return
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/aicat-textures"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for kind in TextureKind.allCases {
    let image = ProceduralTextures.render(kind)
    write(image, to: URL(fileURLWithPath: "\(out)/\(kind.rawValue).png"))
}
// Skies of three worlds (same numbers as Theme.palette): garden, theater, lookout.
let skies: [(String, SkyColors)] = [
    ("sky_garden", SkyColors(top: (0.62, 0.84, 0.98), horizon: (1, 1, 1), ground: (0.47, 0.72, 0.38))),
    ("sky_theater", SkyColors(top: (0.35, 0.25, 0.45), horizon: (1, 1, 1), ground: (0.55, 0.25, 0.30))),
    ("sky_lookout", SkyColors(top: (0.98, 0.80, 0.60), horizon: (1, 1, 1), ground: (0.50, 0.60, 0.45))),
]
for (name, colors) in skies {
    write(ProceduralSky.render(colors), to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("wrote \(TextureKind.allCases.count + skies.count) PNGs to \(out)")
