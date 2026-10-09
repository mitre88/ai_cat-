import Foundation

/// Last gate before any generated text reaches a child. Conservative on purpose: when in doubt, drop it
/// and let the scripted line play instead.
enum KidSafeFilter {
    static let blockedFragments: [String] = [
        "http", "www.", "@", ".com", "kill", "die", "dead", "blood", "gun", "knife", "sex", "drug", "stupid", "hate", "idiot",
        "address", "phone", "password", "matar", "muert", "sangre", "pistola", "cuchillo", "sexo", "droga", "estúpid",
        "odio", "idiota", "dirección", "teléfono", "contraseña", "instagram", "tiktok", "youtube",
    ]

    /// Returns a cleaned line or nil when the text must not be shown.
    static func sanitize(_ raw: String, maxWords: Int) -> String? {
        var text = raw.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
        guard !text.isEmpty else { return nil }
        let lowered = text.lowercased()
        for fragment in blockedFragments where lowered.contains(fragment) {
            return nil
        }
        // No phone numbers, codes or long digit runs.
        var digitRun = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                digitRun += 1
                if digitRun >= 4 { return nil }
            } else {
                digitRun = 0
            }
        }
        let words = text.split(separator: " ")
        if words.count > maxWords {
            // Keep the first sentence if it fits, otherwise refuse.
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            if let first = sentences.first?.trimmingCharacters(in: .whitespaces), !first.isEmpty,
               first.split(separator: " ").count <= maxWords {
                return first + "."
            }
            return nil
        }
        return text
    }
}
