import Foundation

public enum DialogMoment: String, Codable, CaseIterable, Sendable {
    case greeting, scenarioIntro, challengeStart, masterIntro, correct, wrong, hint, aiLearned, aiNeedsMore,
         aiSorted, challengeComplete, scenarioComplete, stageUp, idle, encouragement, locked, trapFound
}

public enum CatEmotion: String, Codable, CaseIterable, Sendable {
    case happy, curious, proud, thinking, sleepy, excited, sad
}

public enum CatGesture: String, Codable, CaseIterable, Sendable {
    case none, nod, jump, tailWag, headTilt, stretch, pounce, sit, shake
}

/// A scripted line AI CAT can say. `id` doubles as the localization key.
public struct DialogLine: Identifiable, Hashable, Codable, Sendable {
    public let key: TextKey
    public let moment: DialogMoment
    public let emotion: CatEmotion
    public let gesture: CatGesture

    public var id: String { key.raw }

    public init(_ key: TextKey, _ moment: DialogMoment, _ emotion: CatEmotion, _ gesture: CatGesture) {
        self.key = key
        self.moment = moment
        self.emotion = emotion
        self.gesture = gesture
    }
}

/// The complete script. ScriptedBrain picks from it; FoundationModelsBrain chooses among these ids.
public enum DialogScript {
    public static let lines: [DialogLine] = [
        DialogLine(TextKey("dialog.greeting.1"), .greeting, .happy, .tailWag),
        DialogLine(TextKey("dialog.greeting.2"), .greeting, .curious, .headTilt),
        DialogLine(TextKey("dialog.greeting.3"), .greeting, .excited, .jump),
        DialogLine(TextKey("dialog.challenge_start.1"), .challengeStart, .curious, .sit),
        DialogLine(TextKey("dialog.challenge_start.2"), .challengeStart, .excited, .pounce),
        DialogLine(TextKey("dialog.master_intro.1"), .masterIntro, .thinking, .stretch),
        DialogLine(TextKey("dialog.correct.1"), .correct, .happy, .nod),
        DialogLine(TextKey("dialog.correct.2"), .correct, .excited, .jump),
        DialogLine(TextKey("dialog.correct.3"), .correct, .proud, .tailWag),
        DialogLine(TextKey("dialog.correct.4"), .correct, .happy, .pounce),
        DialogLine(TextKey("dialog.wrong.1"), .wrong, .thinking, .headTilt),
        DialogLine(TextKey("dialog.wrong.2"), .wrong, .curious, .shake),
        DialogLine(TextKey("dialog.wrong.3"), .wrong, .happy, .sit),
        DialogLine(TextKey("dialog.hint.1"), .hint, .thinking, .headTilt),
        DialogLine(TextKey("dialog.hint.2"), .hint, .curious, .nod),
        DialogLine(TextKey("dialog.ai_learned.1"), .aiLearned, .excited, .jump),
        DialogLine(TextKey("dialog.ai_learned.2"), .aiLearned, .proud, .tailWag),
        DialogLine(TextKey("dialog.ai_needs_more.1"), .aiNeedsMore, .thinking, .headTilt),
        DialogLine(TextKey("dialog.ai_needs_more.2"), .aiNeedsMore, .curious, .sit),
        DialogLine(TextKey("dialog.ai_sorted.1"), .aiSorted, .proud, .pounce),
        DialogLine(TextKey("dialog.challenge_complete.1"), .challengeComplete, .proud, .jump),
        DialogLine(TextKey("dialog.challenge_complete.2"), .challengeComplete, .happy, .tailWag),
        DialogLine(TextKey("dialog.challenge_complete.3"), .challengeComplete, .excited, .stretch),
        DialogLine(TextKey("dialog.scenario_complete.1"), .scenarioComplete, .proud, .jump),
        DialogLine(TextKey("dialog.scenario_complete.2"), .scenarioComplete, .excited, .pounce),
        DialogLine(TextKey("dialog.stage_up.1"), .stageUp, .excited, .stretch),
        DialogLine(TextKey("dialog.stage_up.2"), .stageUp, .proud, .jump),
        DialogLine(TextKey("dialog.idle.1"), .idle, .sleepy, .sit),
        DialogLine(TextKey("dialog.idle.2"), .idle, .curious, .headTilt),
        DialogLine(TextKey("dialog.idle.3"), .idle, .happy, .tailWag),
        DialogLine(TextKey("dialog.encouragement.1"), .encouragement, .happy, .nod),
        DialogLine(TextKey("dialog.encouragement.2"), .encouragement, .curious, .tailWag),
        DialogLine(TextKey("dialog.encouragement.3"), .encouragement, .excited, .jump),
        DialogLine(TextKey("dialog.locked.1"), .locked, .sleepy, .sit),
        DialogLine(TextKey("dialog.trap_found.1"), .trapFound, .thinking, .shake),
        DialogLine(TextKey("dialog.s1.intro"), .scenarioIntro, .curious, .headTilt),
        DialogLine(TextKey("dialog.s2.intro"), .scenarioIntro, .curious, .sit),
        DialogLine(TextKey("dialog.s3.intro"), .scenarioIntro, .thinking, .headTilt),
        DialogLine(TextKey("dialog.s4.intro"), .scenarioIntro, .excited, .pounce),
        DialogLine(TextKey("dialog.s5.intro"), .scenarioIntro, .curious, .stretch),
        DialogLine(TextKey("dialog.s6.intro"), .scenarioIntro, .thinking, .nod),
        DialogLine(TextKey("dialog.s7.intro"), .scenarioIntro, .curious, .headTilt),
        DialogLine(TextKey("dialog.s8.intro"), .scenarioIntro, .happy, .tailWag),
        DialogLine(TextKey("dialog.s9.intro"), .scenarioIntro, .thinking, .sit),
        DialogLine(TextKey("dialog.s10.intro"), .scenarioIntro, .excited, .jump),
    ]

    public static func lines(for moment: DialogMoment) -> [DialogLine] {
        lines.filter { $0.moment == moment }
    }

    /// A line for the moment, cycling through variants.
    public static func line(for moment: DialogMoment, variant: Int) -> DialogLine? {
        let options = lines(for: moment)
        guard !options.isEmpty else { return nil }
        let index = ((variant % options.count) + options.count) % options.count
        return options[index]
    }

    public static func scenarioIntro(_ id: ScenarioID) -> DialogLine? {
        lines.first { $0.moment == .scenarioIntro && $0.key.raw == "dialog.\(id.code).intro" }
    }

    public static func line(id: String) -> DialogLine? {
        lines.first { $0.id == id }
    }
}
