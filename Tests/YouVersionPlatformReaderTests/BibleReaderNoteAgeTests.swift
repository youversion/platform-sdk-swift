import Foundation
import Testing
@testable import YouVersionPlatformReader

struct BibleReaderNoteAgeTests {
    @Test(arguments: [
        (0.0, "Now"), (59, "Now"), (60, "1m"), (180, "3m"),
        (239, "3m"), (3599, "59m"), (14400, "4h"), (345600, "4d"), (604800, "7d"), (-60, "Now"),
    ])
    func compactAgesUseCompletedUnits(elapsed: Double, expected: String) {
        let date = Date(timeIntervalSince1970: 0)
        #expect(BibleReaderNoteAge.ageText(since: date, now: date.addingTimeInterval(elapsed), locale: Locale(identifier: "en_US")) == expected)
    }

    @Test
    func parsesBothTimestampPrecisionsAndRejectsMalformedDates() throws {
        let whole = try #require(BibleReaderNoteAge.date(from: "2026-11-11T12:00:00Z"))
        let fraction = try #require(BibleReaderNoteAge.date(from: "2026-11-11T12:00:00.123Z"))
        let offset = try #require(BibleReaderNoteAge.date(from: "2026-11-11T06:00:00-06:00"))
        #expect(abs(fraction.timeIntervalSince(whole) - 0.123) < 0.001)
        #expect(offset == whole)
        #expect(BibleReaderNoteAge.date(from: "invalid") == nil)
    }

    @Test
    func usesLocaleSpecificUnitAbbreviations() {
        let date = Date(timeIntervalSince1970: 0)
        let now = date.addingTimeInterval(345600)
        let french = BibleReaderNoteAge.ageText(since: date, now: now, locale: Locale(identifier: "fr_FR"))
        #expect(french.contains("j"))
        #expect(!french.contains("d"))
        #expect(BibleReaderNoteAge.ageText(since: now, now: now, locale: Locale(identifier: "fr_FR")) == "Maintenant")
    }
}
