import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - Codable

@Test func decodedBookUSFMIsUppercased() throws {
    let json = """
    {"versionId":1,"bookUSFM":"gen","chapter":1,"verseStart":1,"verseEnd":1}
    """
    let ref = try JSONDecoder().decode(BibleReference.self, from: Data(json.utf8))
    #expect(ref.bookUSFM == "GEN")
}

@Test func decodedVerseReferenceRoundTrips() throws {
    let original = BibleReference(versionId: 1, bookUSFM: "REV", chapter: 22, verse: 21)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BibleReference.self, from: data)
    #expect(decoded.bookUSFM == original.bookUSFM)
    #expect(decoded.versionId == original.versionId)
    #expect(decoded.chapter == original.chapter)
    #expect(decoded.verseStart == original.verseStart)
    #expect(decoded.verseEnd == original.verseEnd)
}

@Test func decodedRangeReferenceRoundTrips() throws {
    let original = BibleReference(versionId: 2, bookUSFM: "PSA", chapter: 23, verseStart: 1, verseEnd: 6)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BibleReference.self, from: data)
    #expect(decoded.bookUSFM == original.bookUSFM)
    #expect(decoded.verseStart == original.verseStart)
    #expect(decoded.verseEnd == original.verseEnd)
}

@Test func decodedChapterReferenceRoundTrips() throws {
    let original = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 3)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BibleReference.self, from: data)
    #expect(decoded.bookUSFM == original.bookUSFM)
    #expect(decoded.chapter == original.chapter)
    #expect(decoded.verseStart == nil)
    #expect(decoded.verseEnd == nil)
}

@Test func decodedLowercaseBookUSFMOverlapsCorrectly() throws {
    let json = """
    {"versionId":1,"bookUSFM":"jhn","chapter":3,"verseStart":16,"verseEnd":16}
    """
    let decoded = try JSONDecoder().decode(BibleReference.self, from: Data(json.utf8))
    let constructed = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 3, verse: 16)
    #expect(decoded.overlaps(with: constructed))
}
