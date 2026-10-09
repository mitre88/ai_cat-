import Foundation
import RealityKit
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
