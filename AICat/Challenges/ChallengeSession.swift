import Foundation
import Observation
import AICatCore

/// Runtime state shared by the board, the stage and the result overlay of one challenge attempt.
@MainActor
@Observable
final class ChallengeSession {
    let spec: ChallengeSpec
    let startedAt = Date()
    private(set) var hintsUsed = 0
    private(set) var isFinished = false
    private(set) var finalAccuracy: Double = 1
    private(set) var outcome: PlayerProfile.RecordOutcome?
    /// Live progress 0…1 shown in the top bar.
    var progress: Double = 0

    init(spec: ChallengeSpec) {
        self.spec = spec
    }

    func noteHint() {
        hintsUsed += 1
    }

    /// Finish the challenge once. Records XP, growth and unlocks through the app model.
    func finish(accuracy: Double, app: AppModel) {
        guard !isFinished else { return }
        isFinished = true
        finalAccuracy = accuracy
        progress = 1
        let result = app.finishChallenge(spec, accuracy: accuracy, hintsUsed: hintsUsed, duration: Date().timeIntervalSince(startedAt))
        outcome = result
        if !result.passed {
            app.say(.encouragement)
        } else if result.scenarioJustCompleted != nil {
            app.say(.scenarioComplete)
        } else if result.stageIncreased {
            app.say(.stageUp)
        } else {
            app.say(.challengeComplete)
        }
    }
}
