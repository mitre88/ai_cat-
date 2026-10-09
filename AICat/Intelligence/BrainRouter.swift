import Foundation
import AICatCore

/// Serialises requests to the generative brain, races them against a timeout and always has a scripted
/// answer ready. The game never waits on the model.
@MainActor
final class BrainRouter: CatBrain {
    static let timeoutSeconds: Double = 4

    private let scripted = ScriptedBrain()
    private let generative = FoundationModelsBrain()
    private var inFlight = false

    func line(for moment: DialogMoment, scenario: ScenarioID?, context: BrainContext) async -> CatLine {
        let fallback = scripted.scriptedLine(for: moment, scenario: scenario, context: context)
        guard FoundationModelsBrain.isAvailable, !inFlight, moment != .scenarioIntro else { return fallback }
        inFlight = true
        defer { inFlight = false }
        let generative = self.generative
        return await Self.withTimeout(seconds: Self.timeoutSeconds, fallback: fallback) {
            await generative.line(for: moment, scenario: scenario, context: context)
        }
    }

    /// Waits (briefly) for a line request in flight instead of refusing: the model runs one request at a time.
    private func waitForTurn() async -> Bool {
        var waited = 0
        while inFlight && waited < 60 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        return !inFlight
    }

    func story(from seeds: [String], context: BrainContext) async -> [String]? {
        guard context.creativeMode, FoundationModelsBrain.isAvailable, await waitForTurn() else { return nil }
        inFlight = true
        defer { inFlight = false }
        let generative = self.generative
        return await Self.withTimeout(seconds: Self.storyTimeoutSeconds, fallback: nil) {
            await generative.story(from: seeds, context: context)
        }
    }

    static let storyTimeoutSeconds: Double = 8

    func answer(question: String, context: BrainContext) async -> String? {
        guard context.creativeMode, FoundationModelsBrain.isAvailable, await waitForTurn() else { return nil }
        inFlight = true
        defer { inFlight = false }
        let generative = self.generative
        return await Self.withTimeout(seconds: Self.storyTimeoutSeconds, fallback: nil) {
            await generative.answer(question: question, context: context)
        }
    }

    static func withTimeout<T: Sendable>(seconds: Double, fallback: T, operation: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            var result = fallback
            if let first = await group.next() {
                result = first ?? fallback
            }
            group.cancelAll()
            return result
        }
    }
}
