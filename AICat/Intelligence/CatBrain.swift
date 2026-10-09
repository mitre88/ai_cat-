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
    /// Three short story sentences grown from the seed words (creative mode only), or nil when the
    /// on-device model is unavailable, declines, or its text does not pass the kid-safe filter.
    func story(from seeds: [String], context: BrainContext) async -> [String]?
    /// A short answer to one of the game's own questions (creative mode only), or nil.
    func answer(question: String, context: BrainContext) async -> String?
}

extension CatBrain {
    func story(from seeds: [String], context: BrainContext) async -> [String]? { nil }
    func answer(question: String, context: BrainContext) async -> String? { nil }
}
