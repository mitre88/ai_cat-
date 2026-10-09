import XCTest
@testable import AICatCore

final class ProceduralSkyTests: XCTestCase {
    private let colors = SkyColors(top: (0.62, 0.84, 0.98), horizon: (1, 1, 1), ground: (0.47, 0.72, 0.38))
    private let field = NoiseField(size: 128, seed: 5)

    func testGradientRunsZenithHorizonGround() {
        let top = ProceduralSky.gradient(colors, 0)
        let horizon = ProceduralSky.gradient(colors, 0.5)
        let ground = ProceduralSky.gradient(colors, 1)
        XCTAssertEqual(top.r, 0.62, accuracy: 1e-9)
        XCTAssertEqual(top.b, 0.98, accuracy: 1e-9)
        XCTAssertEqual(horizon.r, 1, accuracy: 1e-9)
        XCTAssertEqual(ground.g, 0.72 * 0.85, accuracy: 1e-9)
        for i in 0...20 {
            let v = Double(i) / 40   // upper half
            let c = ProceduralSky.gradient(colors, v)
            XCTAssert(c.r >= 0.62 - 1e-9 && c.r <= 1 + 1e-9, "red out of band at v=\(v)")
            XCTAssert(c.b >= 0.98 - 1e-9 && c.b <= 1 + 1e-9, "blue out of band at v=\(v)")
        }
    }

    /// The seam at u = 0 / u = 1 (behind the camera) must be invisible: every term is periodic in u.
    func testSkyIsSeamlessAroundTheHorizon() {
        for i in 0...32 {
            let v = Double(i) / 32
            let a = ProceduralSky.color(colors, u: 0, v: v, field: field)
            let b = ProceduralSky.color(colors, u: 1, v: v, field: field)
            XCTAssertEqual(a.r, b.r, accuracy: 1e-9, "v=\(v)")
            XCTAssertEqual(a.g, b.g, accuracy: 1e-9, "v=\(v)")
            XCTAssertEqual(a.b, b.b, accuracy: 1e-9, "v=\(v)")
        }
    }

    func testCloudsStayAboveTheHorizonAndFadeIntoIt() {
        for i in 0..<64 {
            let u = Double(i) / 64
            XCTAssertEqual(ProceduralSky.cloudDensity(u: u, v: 0.5, field: field), 0)
            XCTAssertEqual(ProceduralSky.cloudDensity(u: u, v: 0.8, field: field), 0)
            XCTAssertEqual(ProceduralSky.cloudDensity(u: u, v: 0.495, field: field), 0)
            let d = ProceduralSky.cloudDensity(u: u, v: 0.2, field: field)
            XCTAssert(d >= 0 && d <= 1)
        }
        var covered = 0
        for i in 0..<64 {
            for j in 0..<24 where ProceduralSky.cloudDensity(u: Double(i) / 64, v: Double(j) / 64, field: field) > 0.5 { covered += 1 }
        }
        let fraction = Double(covered) / Double(64 * 24)
        XCTAssert(fraction > 0.05 && fraction < 0.6, "cloud cover \(fraction) should be a few clouds, not overcast")
    }

    func testSunIsRoundAndSitsWhereTheLightComesFrom() {
        XCTAssertEqual(ProceduralSky.angleToSun(u: ProceduralSky.sunU, v: ProceduralSky.sunV), 0, accuracy: 1e-9)
        XCTAssertEqual(ProceduralSky.sunlight(u: ProceduralSky.sunU, v: ProceduralSky.sunV).disc, 1, accuracy: 1e-9)
        XCTAssertEqual(ProceduralSky.sunlight(u: ProceduralSky.sunU + 0.5, v: 1 - ProceduralSky.sunV).disc, 0, accuracy: 1e-9, "opposite side of the sky")
        // Same angular distance left and right of the sun along its row: the disc is symmetric on the sphere.
        let left = ProceduralSky.angleToSun(u: ProceduralSky.sunU - 0.02, v: ProceduralSky.sunV)
        let right = ProceduralSky.angleToSun(u: ProceduralSky.sunU + 0.02, v: ProceduralSky.sunV)
        XCTAssertEqual(left, right, accuracy: 1e-9)
        let image = ProceduralSky.render(colors, width: 128, height: 64)
        XCTAssertEqual(image, ProceduralSky.render(colors, width: 128, height: 64), "deterministic")
        // The disc's centroid in the image is the sun's (u, v); its centre pixel saturates to white.
        var sumX = 0.0, sumY = 0.0, count = 0.0
        for y in 0..<64 {
            for x in 0..<128 {
                XCTAssertEqual(image.pixel(x, y).a, 255)
                if ProceduralSky.sunlight(u: (Double(x) + 0.5) / 128, v: (Double(y) + 0.5) / 64).disc > 0.5 {
                    sumX += Double(x) + 0.5
                    sumY += Double(y) + 0.5
                    count += 1
                }
            }
        }
        XCTAssert(count > 4, "the disc must cover a few pixels at 128 × 64")
        XCTAssertEqual(sumX / count, ProceduralSky.sunU * 128, accuracy: 1.0)
        XCTAssertEqual(sumY / count, ProceduralSky.sunV * 64, accuracy: 1.0)
        let centre = image.pixel(Int(ProceduralSky.sunU * 128), Int(ProceduralSky.sunV * 64))
        XCTAssertEqual(Int(centre.r) + Int(centre.g) + Int(centre.b), 255 * 3, "the sun's centre is pure white")
    }
}
