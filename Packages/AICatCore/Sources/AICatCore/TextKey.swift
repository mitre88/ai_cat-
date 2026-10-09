import Foundation

/// A localization key owned by the app's String Catalog. The core package never resolves text;
/// it only hands keys to the app, which looks them up through `L10n` in the selected language.
public struct TextKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}
