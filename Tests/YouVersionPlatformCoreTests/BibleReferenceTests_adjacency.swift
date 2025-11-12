@testable import YouVersionPlatformCore
import Testing

// MARK: - Test Adjacent/Overlapping check

@Test
func testAdjacent_individualVerses() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 4)
    
    #expect(ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(ref2.isAdjacentOrOverlapping(with: ref1))  // order doesn't matter
}

@Test
func testAdjacent_verseRangesNotOverlapping() {
    // 1-3 contiguous with 4-6
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 4, verseEnd: 6)
    
    #expect(ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(ref2.isAdjacentOrOverlapping(with: ref1))
}

@Test
func testAdjacent_verseRangesOverlapping() {
    // 1-3 contiguous with 4-6
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 4)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 6)
    
    #expect(ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(ref2.isAdjacentOrOverlapping(with: ref1))
}

@Test
func testNotAdjacent_differentBook() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 1, verse: 1)
    
    #expect(!ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(!ref2.isAdjacentOrOverlapping(with: ref1))
}

@Test
func testNotAdjacent_differentChapter() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 1)
    
    #expect(!ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(!ref2.isAdjacentOrOverlapping(with: ref1))
}

@Test
func testNotAdjacent_verseGap() {
    // 1-3 not contiguous with 5-6
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 6)
    
    #expect(!ref1.isAdjacentOrOverlapping(with: ref2))
    #expect(!ref2.isAdjacentOrOverlapping(with: ref1))
}


