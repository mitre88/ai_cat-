import Foundation
import AICatCore

/// JSON persistence of the player profile in Application Support (local only, never synced).
final class ProgressStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let base: URL
        if let directory {
            base = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            base = support.appendingPathComponent("AICat", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("profile.json")
    }

    func load() -> PlayerProfile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PlayerProfile.self, from: data)
    }

    func save(_ profile: PlayerProfile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
