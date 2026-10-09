import Foundation
import AICatCore

/// `-AICatSmoke` launch argument (CI and `Tools/simulator_smoke.sh`): skip onboarding, open the map and, once
/// the home world has attached with its textures and sky and rendered a few frames, print a report and exit 0.
/// Catches start-up crashes and silent RealityKit failures (textures, sky, meshes, lights) without a human.
enum SmokeMode {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-AICatSmoke")
    static let requiredFrames = 60
    nonisolated(unsafe) private static var frames = 0
    nonisolated(unsafe) private static var reported = false

    static func worldAttached(theme: WorldTheme, textures: Int, expected: Int, sky: Bool, usdz: Bool) {
        guard isActive else { return }
        report("world=\(theme.rawValue) textures=\(textures)/\(expected) sky=\(sky) usdz=\(usdz)")
    }

    /// One rendered frame of the stage; ends the process with the verdict once enough frames ran.
    static func frame() {
        guard isActive, !reported else { return }
        frames += 1
        if frames >= requiredFrames {
            reported = true
            report("frames=\(frames) OK")
            exit(0)
        }
    }

    private static func report(_ text: String) {
        print("AICAT_SMOKE: \(text)")
        fflush(stdout)
    }
}
