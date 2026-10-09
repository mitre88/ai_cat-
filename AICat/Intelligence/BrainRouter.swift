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
