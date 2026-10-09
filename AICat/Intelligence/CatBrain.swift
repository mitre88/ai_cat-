import Foundation
import AICatCore

/// One thing AI CAT says, with how it feels and moves while saying it.
struct CatLine: Equatable, Sendable {
    var text: String
    var emotion: CatEmotion
    var gesture: CatGesture
    /// Script line id when the line comes from the script (nil for generated text).
    var lineID: String?

    static let silent = CatLine(text: "", emotion: .happy, gesture: .none, lineID: nil)
}

/// What a brain knows about the player when choosing a line. Never contains personal data.
struct BrainContext: Equatable, Sendable {
    var language: L10n.Language
    var ageBand: AgeBand
    var catName: String
    var creativeMode: Bool
}

/// Source of AI CAT's lines. `ScriptedBrain` is the complete game; `FoundationModelsBrain` is polish.
protocol CatBrain: AnyObject {
    func line(for moment: DialogMoment, scenario: ScenarioID?, context: BrainContext) async -> CatLine
}
