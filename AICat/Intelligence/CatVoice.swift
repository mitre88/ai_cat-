import AVFoundation
import Foundation

/// On-device text-to-speech for AI CAT. Child-like pitch, slow rate, best available voice per language.
@MainActor
final class CatVoice {
    private let synthesizer = AVSpeechSynthesizer()
    var isEnabled = true

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func speak(_ text: String, language: L10n.Language) {
        guard isEnabled, !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.25
        utterance.volume = 0.9
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private static func bestVoice(for language: L10n.Language) -> AVSpeechSynthesisVoice? {
        let candidates: [String]
        switch language {
        case .spanish: candidates = ["es-MX", "es-US", "es-ES"]
        case .english: candidates = ["en-US", "en-GB", "en-AU"]
        }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for code in candidates {
            let matches = voices.filter { $0.language == code }
            if let best = matches.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
                return best
            }
        }
        return AVSpeechSynthesisVoice(language: candidates[0])
    }
}
