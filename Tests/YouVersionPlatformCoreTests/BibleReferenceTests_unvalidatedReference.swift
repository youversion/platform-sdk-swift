@testable import YouVersionPlatformCore
import Testing

// MARK: - Test unvalidatedReference()

@Test
func testUnvalidatedReference_singleVerse() throws {
    let ref = try #require(BibleReference.unvalidatedReference(with: "GEN.1.3", versionId: 1))
    let expected = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 3)
    #expect(ref == expected)
}

@Test
func testUnvalidatedReference_verseRange() throws {
    let ref = try #require(BibleReference.unvalidatedReference(with: "GEN.1.3-5", versionId: 1))
    let expected = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    #expect(ref == expected)
}

@Test
func testUnvalidatedReference_fullRangeWithChapter() throws {
    let ref = try #require(BibleReference.unvalidatedReference(with: "GEN.1.3-1.5", versionId: 1))
    let expected = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    #expect(ref == expected)
}

@Test
func testUnvalidatedReference_fullRangeWithBook() throws {
    let ref = try #require(BibleReference.unvalidatedReference(with: "GEN.1.3-GEN.1.5", versionId: 1))
    let expected = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    #expect(ref == expected)
}

@Test
func testUnvalidatedReference_invalidBookMismatch() {
    let ref = BibleReference.unvalidatedReference(with: "GEN.1.3-EXO.1.5", versionId: 1)
    #expect(ref == nil)
}

@Test
func testUnvalidatedReference_invalidVerseOrder() {
    let ref = BibleReference.unvalidatedReference(with: "GEN.1.5-3", versionId: 1)
    #expect(ref == nil)
}

@Test
func testUnvalidatedReference_chapterOnly() throws {
    let ref = try #require(BibleReference.unvalidatedReference(with: "GEN.1", versionId: 1))
    let expected = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 1)
    #expect(ref == expected)
}


