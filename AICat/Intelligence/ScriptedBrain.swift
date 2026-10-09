import Foundation
import AICatCore

/// Rule-based brain: cycles through the scripted variants of each moment, localized in the chosen language.
final class ScriptedBrain: CatBrain {
    private var counters: [DialogMoment: Int] = [:]

    func line(for moment: DialogMoment, scenario: ScenarioID?, context: BrainContext) async -> CatLine {
        scriptedLine(for: moment, scenario: scenario, context: context)
    }

    /// Synchronous variant, also used as the fallback of other brains.
    func scriptedLine(for moment: DialogMoment, scenario: ScenarioID?, context: BrainContext) -> CatLine {
        let line: DialogLine?
        if moment == .scenarioIntro, let scenario {
            line = DialogScript.scenarioIntro(scenario)
        } else {
            let n = counters[moment, default: 0]
            counters[moment] = n + 1
            line = DialogScript.line(for: moment, variant: n)
        }
        guard let line else { return .silent }
        return Self.render(line, context: context)
    }

    static func render(_ line: DialogLine, context: BrainContext) -> CatLine {
        let raw = L10n.string(line.key.raw, language: context.language)
        let text = raw.replacingOccurrences(of: "AI CAT", with: context.catName)
        return CatLine(text: text, emotion: line.emotion, gesture: line.gesture, lineID: line.id)
    }
}
