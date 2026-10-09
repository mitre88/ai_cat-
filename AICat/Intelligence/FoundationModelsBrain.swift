import Foundation
import AICatCore
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
/// Structured outputs requested from the on-device model. The only file that uses the macros.
@Generable
struct ScriptLineChoice {
    @Guide(description: "Zero-based index of the script line that fits the situation best.")
    var index: Int
}

@Generable
struct CreativeCatLine {
    @Guide(description: "One or two short, kind, playful sentences a kitten says to a child, in the requested language. No questions about personal data, no links, no numbers.")
    var text: String
    @Guide(description: "One of: happy, curious, proud, thinking, sleepy, excited")
    var emotion: String
}

@Generable
struct ModelStory {
    @Guide(description: "Exactly three short, kind, playful sentences for a child, in the requested language, each about the given character, place and object. No real people, nothing scary, no links, no numbers.")
    var sentences: [String]
}
#endif

/// Picks AI CAT's line with Apple Intelligence (Foundation Models), entirely on device.
/// Safe by construction: by default the model only CHOOSES among pre-written script lines; in creative mode
/// (parent opt-in) it may write a short line that still passes `KidSafeFilter`. Any error → scripted line.
@MainActor
final class FoundationModelsBrain: CatBrain {
    private let scripted = ScriptedBrain()
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    private var sessionKey: String = ""
    #endif

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    static func supports(_ locale: Locale) -> Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.supportsLocale(locale)
        #else
        return false
        #endif
    }

    func line(for moment: DialogMoment, scenario: ScenarioID?, context: BrainContext) async -> CatLine {
        let fallback = scripted.scriptedLine(for: moment, scenario: scenario, context: context)
        #if canImport(FoundationModels)
        guard Self.isAvailable, Self.supports(context.language.locale), moment != .scenarioIntro else { return fallback }
        let candidates = DialogScript.lines(for: moment)
        guard !candidates.isEmpty else { return fallback }
        do {
            let session = makeSession(for: context)
            if context.creativeMode {
                let response = try await session.respond(to: creativePrompt(moment: moment, context: context), generating: CreativeCatLine.self)
                let maxWords = context.ageBand.maxSentenceWords * 2
                guard let text = KidSafeFilter.sanitize(response.content.text, maxWords: maxWords) else { return fallback }
                let emotion = CatEmotion(rawValue: response.content.emotion.lowercased()) ?? fallback.emotion
                return CatLine(text: text, emotion: emotion, gesture: fallback.gesture, lineID: nil)
            } else {
                guard candidates.count > 1 else { return fallback }
                let response = try await session.respond(to: choicePrompt(moment: moment, candidates: candidates, context: context), generating: ScriptLineChoice.self)
                let index = response.content.index
                guard candidates.indices.contains(index) else { return fallback }
                return ScriptedBrain.render(candidates[index], context: context)
            }
        } catch {
            return fallback
        }
        #else
        return fallback
        #endif
    }

    func story(from seeds: [String], context: BrainContext) async -> [String]? {
        #if canImport(FoundationModels)
        guard context.creativeMode, Self.isAvailable, Self.supports(context.language.locale), seeds.count == 3 else { return nil }
        do {
            let session = makeSession(for: context)
            let response = try await session.respond(to: storyPrompt(seeds: seeds, context: context), generating: ModelStory.self)
            let maxWords = context.ageBand.maxSentenceWords + 6
            let cleaned = response.content.sentences.prefix(3).compactMap { KidSafeFilter.sanitize($0, maxWords: maxWords) }
            return cleaned.count == 3 ? Array(cleaned) : nil
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    func answer(question: String, context: BrainContext) async -> String? {
        #if canImport(FoundationModels)
        guard context.creativeMode, Self.isAvailable, Self.supports(context.language.locale) else { return nil }
        do {
            let session = makeSession(for: context)
            let prompt = "The child asks: \"\(question)\". Answer in at most two short sentences. If you are not sure, say that you are not sure."
            let response = try await session.respond(to: prompt, generating: CreativeCatLine.self)
            return KidSafeFilter.sanitize(response.content.text, maxWords: context.ageBand.maxSentenceWords * 2 + 4)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    private func storyPrompt(seeds: [String], context: BrainContext) -> String {
        let languageName = context.language == .spanish ? "Spanish" : "English"
        return "Write a tiny story in \(languageName) for a child, in exactly three short sentences (at most \(context.ageBand.maxSentenceWords + 4) words each). " +
            "Character: \(seeds[0]). Place: \(seeds[1]). Object: \(seeds[2]). Kind and playful, with a happy ending."
    }

    private func makeSession(for context: BrainContext) -> LanguageModelSession {
        let key = "\(context.language.rawValue)-\(context.ageBand.rawValue)-\(context.catName)"
        if let session, sessionKey == key { return session }
        let languageName = context.language == .spanish ? "Spanish" : "English"
        let instructions = """
        You are \(context.catName), a curious, kind black kitten who teaches children aged \(context.ageBand.ageRange.lowerBound) to \(context.ageBand.ageRange.upperBound) \
        the basics of artificial intelligence inside a game. Always answer in \(languageName). Use at most \(context.ageBand.maxSentenceWords) words per sentence \
        and at most two sentences. Be warm and playful, never scary. Never ask for personal information, never mention the internet, \
        links, phone numbers or products. If unsure, say something encouraging about learning.
        """
        let created = LanguageModelSession(instructions: instructions)
        created.prewarm(promptPrefix: nil)
        session = created
        sessionKey = key
        return created
    }

    private func choicePrompt(moment: DialogMoment, candidates: [DialogLine], context: BrainContext) -> String {
        let listed = candidates.enumerated().map { pair in
            "\(pair.offset): \(ScriptedBrain.render(pair.element, context: context).text)"
        }.joined(separator: "\n")
        return "Situation: \(moment.rawValue). Choose the index of the line that fits best for a child right now.\n\(listed)"
    }

    private func creativePrompt(moment: DialogMoment, context: BrainContext) -> String {
        "Situation in the game: \(moment.rawValue). Say one short, kind line to the child as the kitten \(context.catName)."
    }
    #endif
}
