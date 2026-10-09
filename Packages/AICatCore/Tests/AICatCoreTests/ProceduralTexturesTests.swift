import XCTest
@testable import AICatCore

final class ProceduralTexturesTests: XCTestCase {
    private let field = NoiseField(size: 64, seed: 17)
    private let colourKinds = TextureKind.allCases.filter { !$0.isNormalMap && $0 != .blobShadow }
    private let normalKinds = TextureKind.allCases.filter { $0.isNormalMap }

    func testNoiseIsPeriodicInBothAxes() {
        for cells in [3, 7, 16] {
            for i in 0...8 {
                let t = Double(i) / 8
                XCTAssertEqual(field.noise(0, t, cellsX: cells, cellsY: cells, salt: 2),
                               field.noise(1, t, cellsX: cells, cellsY: cells, salt: 2), accuracy: 1e-12)
                XCTAssertEqual(field.noise(t, 0, cellsX: cells, cellsY: cells, salt: 2),
                               field.noise(t, 1, cellsX: cells, cellsY: cells, salt: 2), accuracy: 1e-12)
                XCTAssertEqual(field.noise(t * 0.9 + 0.05, 0.3, cellsX: cells, cellsY: 5, salt: 4),
                               field.noise(t * 0.9 + 1.05, 1.3, cellsX: cells, cellsY: 5, salt: 4), accuracy: 1e-9)
            }
        }
    }

    func testNoiseAndFBMStayInTheUnitInterval() {
        for i in 0...32 {
            for j in 0...32 {
                let u = Double(i) / 32
                let v = Double(j) / 32
                let n = field.noise(u, v, cellsX: 9, cellsY: 4, salt: 1)
                let f = field.fbm(u, v, cells: 5, octaves: 4, salt: 3)
                XCTAssert(n >= 0 && n <= 1, "noise out of range: \(n)")
                XCTAssert(f >= 0 && f <= 1, "fbm out of range: \(f)")
            }
        }
    }

    /// Every surface is periodic with period 1: the texture repeats across the ground without a seam.
    func testEverySurfaceMatchesAtTheSeam() {
        for kind in colourKinds {
            for i in 0...32 {
                let t = Double(i) / 32
                let left = field.color(kind, 0, t), right = field.color(kind, 1, t)
                let top = field.color(kind, t, 0), bottom = field.color(kind, t, 1)
                XCTAssertEqual(left.r, right.r, accuracy: 1e-9, "\(kind) seam in u")
                XCTAssertEqual(left.g, right.g, accuracy: 1e-9, "\(kind) seam in u")
                XCTAssertEqual(left.b, right.b, accuracy: 1e-9, "\(kind) seam in u")
                XCTAssertEqual(top.r, bottom.r, accuracy: 1e-9, "\(kind) seam in v")
                XCTAssertEqual(top.g, bottom.g, accuracy: 1e-9, "\(kind) seam in v")
                XCTAssertEqual(top.b, bottom.b, accuracy: 1e-9, "\(kind) seam in v")
            }
        }
        for kind in normalKinds {
            for i in 0...32 {
                let t = Double(i) / 32
                XCTAssertEqual(field.height(kind, 0, t), field.height(kind, 1, t), accuracy: 1e-9, "\(kind) seam in u")
                XCTAssertEqual(field.height(kind, t, 0), field.height(kind, t, 1), accuracy: 1e-9, "\(kind) seam in v")
            }
        }
    }

    func testEveryKindRendersADeterministicFullBuffer() {
        for kind in TextureKind.allCases {
            let a = ProceduralTextures.render(kind, size: 24)
            let b = ProceduralTextures.render(kind, size: 24)
            XCTAssertEqual(a.width, 24)
            XCTAssertEqual(a.height, 24)
            XCTAssertEqual(a.pixels.count, 24 * 24 * 4, "\(kind)")
            XCTAssertEqual(a, b, "\(kind) must render the same bytes every time")
        }
        XCTAssertNotEqual(ProceduralTextures.render(.grass, size: 24), ProceduralTextures.render(.stone, size: 24))
        XCTAssertEqual(Set(TextureKind.allCases.map(\.seed)).count, TextureKind.allCases.count, "seeds must differ per kind")
        for kind in TextureKind.allCases {
            let size = kind.preferredSize
            XCTAssert(size >= 128 && size <= 512 && size & (size - 1) == 0, "\(kind) preferred size \(size)")
        }
    }

    /// Colour textures are structure: opaque, bright on average (the palette tint supplies the colour),
    /// with visible variation.
    func testColourTexturesAreOpaqueBrightAndVaried() {
        for kind in colourKinds {
            let image = ProceduralTextures.render(kind, size: 48)
            var sum = 0.0
            var minimum = 255
            var maximum = 0
            for y in 0..<48 {
                for x in 0..<48 {
                    let p = image.pixel(x, y)
                    XCTAssertEqual(p.a, 255, "\(kind) must be opaque")
                    let luminance = (Int(p.r) + Int(p.g) + Int(p.b)) / 3
                    sum += Double(luminance) / 255
                    minimum = min(minimum, luminance)
                    maximum = max(maximum, luminance)
                }
            }
            let mean = sum / Double(48 * 48)
            XCTAssert(mean > 0.55 && mean <= 1.0, "\(kind) mean brightness \(mean)")
            XCTAssert(maximum - minimum >= 20, "\(kind) has no visible structure (range \(maximum - minimum))")
        }
    }

    /// Normal maps decode to unit vectors that mostly point out of the surface (+z).
    func testNormalMapsDecodeToUnitVectorsFacingOut() {
        for kind in normalKinds {
            let image = ProceduralTextures.render(kind, size: 32)
            var sumZ = 0.0
            for y in 0..<32 {
                for x in 0..<32 {
                    let p = image.pixel(x, y)
                    XCTAssertEqual(p.a, 255)
                    let nx = Double(p.r) / 255 * 2 - 1
                    let ny = Double(p.g) / 255 * 2 - 1
                    let nz = Double(p.b) / 255 * 2 - 1
                    XCTAssertEqual((nx * nx + ny * ny + nz * nz).squareRoot(), 1, accuracy: 0.03, "\(kind) at \(x),\(y)")
                    XCTAssert(nz > 0.2, "\(kind) normal folds under the surface at \(x),\(y)")
                    sumZ += nz
                }
            }
            XCTAssert(sumZ / Double(32 * 32) > 0.8, "\(kind) relief too steep on average")
        }
    }

    /// The contact shadow is a premultiplied disc whose every channel is the falloff: opaque in the middle,
    /// clear at the edge, never getting darker again as it fades.
    func testBlobShadowFadesMonotonicallyToClear() {
        let image = ProceduralTextures.render(.blobShadow, size: 64)
        XCTAssertEqual(image.pixel(32, 32).a, 255)
        XCTAssertEqual(image.pixel(0, 0).a, 0)
        XCTAssertEqual(image.pixel(0, 32).a, 0)
        XCTAssertEqual(image.pixel(32, 0).a, 0)
        var previous = 255
        for x in 32..<64 {
            let p = image.pixel(x, 32)
            XCTAssertEqual(p.r, p.a, "premultiplied white: colour equals alpha")
            XCTAssertEqual(p.g, p.a)
            XCTAssertEqual(p.b, p.a)
            XCTAssert(Int(p.a) <= previous, "alpha must not increase outwards (x=\(x))")
            previous = Int(p.a)
        }
        XCTAssertEqual(field.blob(0.5, 0.5), 1, accuracy: 1e-12)
        XCTAssertEqual(field.blob(0.5, 0.0), 0, accuracy: 1e-12)
        XCTAssertEqual(field.blob(0.5, 0.56), 1, accuracy: 1e-12, "flat core of the shadow")
    }
}
