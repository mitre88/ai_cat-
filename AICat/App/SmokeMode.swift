import Foundation
import AICatCore

/// Launch argument `-AICatSmoke` (CI and `Tools/simulator_smoke.sh`): skip onboarding, open the map and, once
/// the home world has attached (textures, sky, cat rig) and rendered `requiredFrames`, print a verdict and exit 0.
/// With the extra argument `tour`, the smoke then drives the whole game: every challenge of every world is
/// pushed, its world must attach and render, its controller must start, postures and growth are exercised on
/// one challenge per world, then it is popped. Any crash or hang turns the CI run red.
@MainActor
enum SmokeMode {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-AICatSmoke")
    static let isTour = isActive && ProcessInfo.processInfo.arguments.contains("tour")
    static let requiredFrames = 60
    static let challengeFrames = 30
    static let challengeTimeout: Double = 60

    private static var frames: [ObjectIdentifier: Int] = [:]
    private static var homeWorld: ObjectIdentifier?
    private static var readyChallenge: (spec: ChallengeSpec, world: WorldModel)?
    private static var tourStarted = false
    private static var finished = false

    // MARK: Hooks (no-ops outside smoke mode)

    static func worldAttached(_ world: WorldModel, theme: WorldTheme, textures: Int, expected: Int, sky: Bool, usdz: Bool) {
        guard isActive else { return }
        if homeWorld == nil { homeWorld = ObjectIdentifier(world) }
        report("world=\(theme.rawValue) textures=\(textures)/\(expected) sky=\(sky) usdz=\(usdz)")
    }

    /// One rendered frame of a stage; the plain smoke ends once the home world has rendered enough of them.
    static func frame(_ world: WorldModel) {
        guard isActive, !finished else { return }
        let id = ObjectIdentifier(world)
        frames[id, default: 0] += 1
        if !isTour, id == homeWorld, frames[id, default: 0] >= requiredFrames {
            finish(ok: true, "frames=\(requiredFrames) OK")
        }
    }

    /// The challenge host created its controller (world prepared, props built).
    static func challengeStarted(_ spec: ChallengeSpec, world: WorldModel) {
        guard isActive else { return }
        readyChallenge = (spec, world)
    }

    /// Starts the tour (once) when the root view appears.
    static func begin(app: AppModel) {
        guard isTour, !tourStarted else { return }
        tourStarted = true
        Task { @MainActor in
            await runTour(app: app)
        }
    }

    // MARK: Tour

    private static func runTour(app: AppModel) async {
        guard await wait(timeout: 90, { homeWorld.map { frames[$0, default: 0] >= requiredFrames } ?? false }) else {
            finish(ok: false, "TIMEOUT home world never rendered \(requiredFrames) frames")
            return
        }
        report("home frames=\(requiredFrames) ok")
        var done = 0
        var total = 0
        for scenarioID in ScenarioID.allCases {
            let scenario = Curriculum.scenario(scenarioID)
            for (index, spec) in scenario.challenges.enumerated() {
                total += 1
                readyChallenge = nil
                app.path.append(spec)
                let started = await wait(timeout: challengeTimeout) { readyChallenge?.spec == spec }
                guard started, let ready = readyChallenge else {
                    finish(ok: false, "TIMEOUT challenge=\(spec.id) (controller never started)")
                    return
                }
                let worldID = ObjectIdentifier(ready.world)
                let rendered = await wait(timeout: challengeTimeout) { frames[worldID, default: 0] >= challengeFrames }
                guard rendered else {
                    finish(ok: false, "TIMEOUT challenge=\(spec.id) (world never rendered \(challengeFrames) frames)")
                    return
                }
                if index == 0 {
                    exercise(ready.world)
                    _ = await wait(timeout: 10) { frames[worldID, default: 0] >= challengeFrames + 10 }
                }
                report("challenge=\(spec.id) ok frames=\(frames[worldID, default: 0])")
                done += 1
                if !app.path.isEmpty { app.path.removeLast() }
                try? await Task.sleep(nanoseconds: 700_000_000)   // let the host disappear and tear down
            }
        }
        finish(ok: done == total, "tour=\(done)/\(total) OK")
    }

    /// Postures (the layouts the Duo code switches between) and the full growth range on one world.
    private static func exercise(_ world: WorldModel) {
        let tabletop = CGRect(x: 0, y: 380, width: 820, height: 24)
        let book = CGRect(x: 400, y: 0, width: 24, height: 820)
        for posture: StagePosture in [.pocket, .world, .lab(division: tabletop), .book(division: book), .world] {
            world.setPosture(posture)
        }
        world.setOpenness(0.3)
        world.setOpenness(1)
        world.setGrowth(1, animated: false)
        world.setGrowth(0, animated: false)
        world.setGrowth(0.5, animated: true)
    }

    private static func wait(timeout: Double, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return condition()
    }

    private static func finish(ok: Bool, _ text: String) {
        finished = true
        report(text)
        exit(ok ? 0 : 2)
    }

    private static func report(_ text: String) {
        print("AICAT_SMOKE: \(text)")
        fflush(stdout)
    }
}
