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

    /// Races `operation` against a timer. Returns the fallback at the deadline even if the operation keeps
    /// running (its late result is discarded), so the game never waits on the model.
    static func withTimeout<T: Sendable>(seconds: Double, fallback: T, operation: @escaping @Sendable () async -> T) async -> T {
        await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
            let once = ResumeOnce(continuation)
            let work = Task {
                let value = await operation()
                once.resume(value)
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                once.resume(fallback)
                work.cancel()
            }
        }
    }

    private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        private let continuation: CheckedContinuation<T, Never>
        init(_ continuation: CheckedContinuation<T, Never>) { self.continuation = continuation }
        func resume(_ value: T) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(returning: value)
        }
    }
}
