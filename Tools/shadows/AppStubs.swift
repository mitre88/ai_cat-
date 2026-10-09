import Foundation
import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Stand-ins for the files that need frameworks the shadows do not model (AVFoundation, CoreGraphics).
@MainActor
final class CatVoice {
    var isEnabled = true
    init() {}
    var isSpeaking: Bool { false }
    func speak(_ text: String, language: L10n.Language) {}
    func stop() {}
}

enum SkyEnvironment {
    @MainActor
    static func resource(for theme: WorldTheme) async -> EnvironmentResource? { nil }
}

// Capture/ (AVFoundation, Vision, Speech): the same surface the controllers and boards use.
@MainActor
@Observable
final class CameraClassifier {
    struct Guess: Equatable, Identifiable, Sendable {
        let id: String
        let label: String
        let confidence: Double
    }
    private(set) var guesses: [Guess] = []
    private(set) var isRunning = false
    private(set) var isDenied = false
    static var isSupported: Bool { false }
    func requestAccess() async -> Bool { false }
    func start() async {}
    func stop() {}
    static func classifySample(emoji: String) async -> [Guess] { [] }
}

struct CameraPreview: View {
    let classifier: CameraClassifier
    var body: some View { EmptyView() }
}

@MainActor
@Observable
final class SpeechListener {
    private(set) var isListening = false
    private(set) var partialText = ""
    private(set) var isDenied = false
    static func isSupported(language: L10n.Language) -> Bool { false }
    func requestAccess() async -> Bool { false }
    func listen(language: L10n.Language, seconds: Double = 7) async -> String? { nil }
    func stop() {}
}
