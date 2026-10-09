import XCTest
@testable import AICatCore

final class CapsuleMeshTests: XCTestCase {
    func testGeometryStaysInsideTheCapsuleAndNormalsAreUnit() {
        let mesh = CapsuleMesh.build(height: 0.30, radius: 0.06, segments: 16, rings: 4)
        XCTAssertEqual(mesh.positions.count, mesh.normals.count)
        XCTAssertEqual(mesh.positions.count, mesh.uvs.count)
        XCTAssertEqual(mesh.positions.count, 2 * 5 * 17)
        XCTAssertEqual(mesh.indices.count % 3, 0)
        var minY: Float = 1, maxY: Float = -1
        for (p, n) in zip(mesh.positions, mesh.normals) {
            XCTAssertLessThanOrEqual((p.x * p.x + p.z * p.z).squareRoot(), 0.06 + 1e-5)
            XCTAssertLessThanOrEqual(abs(p.y), 0.15 + 1e-5)
            XCTAssertEqual((n * n).sum().squareRoot(), 1, accuracy: 1e-5)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        XCTAssertEqual(minY, -0.15, accuracy: 1e-5, "bottom pole")
        XCTAssertEqual(maxY, 0.15, accuracy: 1e-5, "top pole")
        for index in mesh.indices { XCTAssertLessThan(Int(index), mesh.positions.count) }
    }

    func testTextureCoordinatesCoverTheUnitSquareAlongTheProfile() {
        let mesh = CapsuleMesh.build(height: 0.30, radius: 0.06, segments: 16, rings: 4)
        let stride = 17
        for (i, uv) in mesh.uvs.enumerated() {
            XCTAssert(uv.x >= 0 && uv.x <= 1 && uv.y >= 0 && uv.y <= 1, "uv out of range \(uv)")
            XCTAssertEqual(uv.x, Float(i % stride) / 16, accuracy: 1e-6, "u runs around the axis")
        }
        XCTAssertEqual(mesh.uvs.first?.y ?? 1, 0, accuracy: 1e-6, "bottom pole v = 0")
        XCTAssertEqual(mesh.uvs.last?.y ?? 0, 1, accuracy: 1e-6, "top pole v = 1")
        // v grows monotonically with the ring (arc length along the profile)
        var previous: Float = -1
        for ring in 0..<(mesh.uvs.count / stride) {
            let v = mesh.uvs[ring * stride].y
            XCTAssertGreaterThanOrEqual(v, previous)
            previous = v
        }
        // the cylinder (from the bottom equator ring to the top equator ring) takes its share of v
        let equatorBottom = mesh.uvs[4 * stride].y
        let equatorTop = mesh.uvs[5 * stride].y
        XCTAssertEqual(equatorTop - equatorBottom, 0.18 / (Float.pi * 0.06 + 0.18), accuracy: 1e-5)
    }

    /// Every triangle faces outwards with counter-clockwise winding (its geometric normal agrees with the
    /// vertex normals) and none is degenerate.
    func testTrianglesWindCounterClockwiseSeenFromOutside() {
        for (height, radius) in [(Float(0.30), Float(0.06)), (0.12, 0.06), (0.5, 0.05)] {
            let mesh = CapsuleMesh.build(height: height, radius: radius, segments: 12, rings: 3)
            var triangles = 0
            for t in stride(from: 0, to: mesh.indices.count, by: 3) {
                let i0 = Int(mesh.indices[t]), i1 = Int(mesh.indices[t + 1]), i2 = Int(mesh.indices[t + 2])
                let p0 = mesh.positions[i0], p1 = mesh.positions[i1], p2 = mesh.positions[i2]
                let e1 = p1 - p0, e2 = p2 - p0
                let cross = SIMD3<Float>(e1.y * e2.z - e1.z * e2.y, e1.z * e2.x - e1.x * e2.z, e1.x * e2.y - e1.y * e2.x)
                let area = (cross * cross).sum().squareRoot()
                XCTAssertGreaterThan(area, 1e-9, "degenerate triangle \(t / 3) for \(height)x\(radius)")
                let n = (mesh.normals[i0] + mesh.normals[i1] + mesh.normals[i2]) / 3
                XCTAssertGreaterThan((cross * n).sum(), 0, "triangle \(t / 3) winds clockwise for \(height)x\(radius)")
                triangles += 1
            }
            XCTAssertEqual(triangles, mesh.indices.count / 3)
        }
    }

    func testSphereWhenHeightEqualsDiameter() {
        let mesh = CapsuleMesh.build(height: 0.1, radius: 0.05, segments: 8, rings: 2)
        for p in mesh.positions {
            XCTAssertEqual((p * p).sum().squareRoot(), 0.05, accuracy: 1e-5)
        }
    }
}
