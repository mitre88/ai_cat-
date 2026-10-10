import SwiftUI
import AICatCore

struct WorldPalette {
    var sky: Color
    var ground: Color
    var primary: Color
    var secondary: Color
    var accent: Color
}

enum Theme {
    static let catBlack = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let eyeGreen = Color(red: 0.16, green: 0.78, blue: 0.62)
    static let mapBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let cardBackground = Color.white
    static let lockedGray = Color(red: 0.82, green: 0.83, blue: 0.86)

    static func palette(for theme: WorldTheme) -> WorldPalette {
        switch theme {
        case .garden: return WorldPalette(sky: Color(red: 0.62, green: 0.84, blue: 0.98), ground: Color(red: 0.50, green: 0.72, blue: 0.44), primary: Color(red: 0.95, green: 0.42, blue: 0.36), secondary: Color(red: 0.98, green: 0.80, blue: 0.30), accent: Color(red: 0.36, green: 0.62, blue: 0.28))
        case .library: return WorldPalette(sky: Color(red: 0.94, green: 0.88, blue: 0.78), ground: Color(red: 0.62, green: 0.45, blue: 0.30), primary: Color(red: 0.55, green: 0.36, blue: 0.62), secondary: Color(red: 0.92, green: 0.70, blue: 0.42), accent: Color(red: 0.30, green: 0.55, blue: 0.75))
        case .workshop: return WorldPalette(sky: Color(red: 0.80, green: 0.86, blue: 0.90), ground: Color(red: 0.55, green: 0.55, blue: 0.58), primary: Color(red: 0.95, green: 0.60, blue: 0.20), secondary: Color(red: 0.35, green: 0.65, blue: 0.85), accent: Color(red: 0.90, green: 0.30, blue: 0.30))
        case .trail: return WorldPalette(sky: Color(red: 0.70, green: 0.88, blue: 0.95), ground: Color(red: 0.76, green: 0.68, blue: 0.50), primary: Color(red: 0.30, green: 0.60, blue: 0.40), secondary: Color(red: 0.85, green: 0.75, blue: 0.40), accent: Color(red: 0.25, green: 0.45, blue: 0.70))
        case .maze: return WorldPalette(sky: Color(red: 0.55, green: 0.60, blue: 0.80), ground: Color(red: 0.52, green: 0.56, blue: 0.68), primary: Color(red: 0.98, green: 0.78, blue: 0.25), secondary: Color(red: 0.55, green: 0.80, blue: 0.95), accent: Color(red: 0.95, green: 0.45, blue: 0.55))
        case .factory: return WorldPalette(sky: Color(red: 0.75, green: 0.78, blue: 0.85), ground: Color(red: 0.45, green: 0.47, blue: 0.52), primary: Color(red: 0.25, green: 0.70, blue: 0.85), secondary: Color(red: 0.95, green: 0.55, blue: 0.25), accent: Color(red: 0.70, green: 0.85, blue: 0.30))
        case .lookout: return WorldPalette(sky: Color(red: 0.98, green: 0.80, blue: 0.60), ground: Color(red: 0.50, green: 0.60, blue: 0.45), primary: Color(red: 0.90, green: 0.40, blue: 0.30), secondary: Color(red: 0.40, green: 0.60, blue: 0.85), accent: Color(red: 0.95, green: 0.75, blue: 0.20))
        case .theater: return WorldPalette(sky: Color(red: 0.35, green: 0.25, blue: 0.45), ground: Color(red: 0.55, green: 0.25, blue: 0.30), primary: Color(red: 0.95, green: 0.80, blue: 0.35), secondary: Color(red: 0.85, green: 0.40, blue: 0.55), accent: Color(red: 0.40, green: 0.80, blue: 0.85))
        case .plaza: return WorldPalette(sky: Color(red: 0.78, green: 0.90, blue: 0.98), ground: Color(red: 0.80, green: 0.78, blue: 0.70), primary: Color(red: 0.30, green: 0.55, blue: 0.85), secondary: Color(red: 0.95, green: 0.65, blue: 0.30), accent: Color(red: 0.40, green: 0.75, blue: 0.50))
        case .lab: return WorldPalette(sky: Color(red: 0.85, green: 0.92, blue: 0.95), ground: Color(red: 0.90, green: 0.92, blue: 0.94), primary: Color(red: 0.55, green: 0.40, blue: 0.90), secondary: Color(red: 0.25, green: 0.80, blue: 0.75), accent: Color(red: 0.95, green: 0.50, blue: 0.65))
        }
    }

    static func emoji(for theme: WorldTheme) -> String {
        switch theme {
        case .garden: return "🌱"
        case .library: return "📚"
        case .workshop: return "🔧"
        case .trail: return "🥾"
        case .maze: return "🧩"
        case .factory: return "🏭"
        case .lookout: return "👀"
        case .theater: return "🎭"
        case .plaza: return "⚖️"
        case .lab: return "🧪"
        }
    }

    static func symbol(for emotion: CatEmotion) -> String {
        switch emotion {
        case .happy: return "face.smiling"
        case .curious: return "questionmark.circle"
        case .proud: return "star.fill"
        case .thinking: return "brain"
        case .sleepy: return "zzz"
        case .excited: return "sparkles"
        case .sad: return "cloud.rain"
        }
    }

    static func symbol(for item: KnowledgeItem) -> String {
        switch item {
        case .collar: return "circle.dashed"
        case .bandana: return "scarf"
        case .glasses: return "eyeglasses"
        case .backpack: return "backpack.fill"
        case .compass: return "safari.fill"
        case .headband: return "waveform.path"
        case .goggles: return "eye.fill"
        case .headphones: return "headphones"
        case .badge: return "checkmark.seal.fill"
        case .graduationCap: return "graduationcap.fill"
        }
    }
}
