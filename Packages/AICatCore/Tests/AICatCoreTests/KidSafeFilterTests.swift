import XCTest
@testable import AICatCore

final class KidSafeFilterTests: XCTestCase {
    func testCleanLinesPass() {
        XCTAssertEqual(KidSafeFilter.sanitize("¡Qué bien lo hiciste!", maxWords: 10), "¡Qué bien lo hiciste!")
        XCTAssertEqual(KidSafeFilter.sanitize("  \"Let's learn together.\"  ", maxWords: 10), "Let's learn together.")
        XCTAssertEqual(KidSafeFilter.sanitize("Line one\nline two", maxWords: 10), "Line one line two")
    }

    func testBlockedContentIsDropped() {
        for text in ["Visit www.example.com now", "Send me your address", "Mi contraseña es gato", "I hate this", "Ve a youtube",
                     "Call 5551234 please", "code 12345"] {
            XCTAssertNil(KidSafeFilter.sanitize(text, maxWords: 20), text)
        }
        XCTAssertNil(KidSafeFilter.sanitize("", maxWords: 10))
        XCTAssertNil(KidSafeFilter.sanitize("   ", maxWords: 10))
    }

    func testShortDigitRunsAreFine() {
        XCTAssertEqual(KidSafeFilter.sanitize("I counted 123 stars", maxWords: 10), "I counted 123 stars")
    }

    func testLongTextKeepsFirstSentenceOrDrops() {
        let long = "This is a long first sentence with many words. And then a second one."
        XCTAssertEqual(KidSafeFilter.sanitize(long, maxWords: 9), "This is a long first sentence with many words.")
        XCTAssertNil(KidSafeFilter.sanitize(long, maxWords: 5), "first sentence too long as well")
        XCTAssertEqual(KidSafeFilter.sanitize("Short enough here.", maxWords: 3), "Short enough here.")
    }
}
