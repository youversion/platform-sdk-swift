@testable import YouVersionPlatformCore
import Testing

// MARK: - Test overlaps function

@Test
func testOverlaps_SameVerse() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_DifferentVerses() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 4)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_VerseRangeOverlaps() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 9)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_VerseRangeNoOverlap() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 7, verseEnd: 9)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_VerseRangeAdjacent() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 6, verseEnd: 8)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_OneContainsOther() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 7)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_SingleVerseInRange() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 5)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_SingleVerseAtRangeBoundary() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_SingleVerseOutsideRange() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 8)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_DifferentChapters() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 3)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_DifferentBooks() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 1, verse: 3)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_DifferentVersions() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 2, bookUSFM: "GEN", chapter: 1, verse: 3)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_ComplexOverlapScenarios() {
    // Test various complex overlap scenarios
    let scenarios: [(BibleReference, BibleReference, Bool)] = [
        // (ref1, ref2, shouldOverlap)
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 15), true),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 15),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10), true),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 6, verseEnd: 10), false),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10), true),
    ]
    
    for (ref1, ref2, shouldOverlap) in scenarios {
        #expect(ref1.overlaps(with: ref2) == shouldOverlap, "Failed for ref1: \(ref1), ref2: \(ref2)")
        #expect(ref2.overlaps(with: ref1) == shouldOverlap, "Failed for ref2: \(ref2), ref1: \(ref1)")
    }
}

@Test
func testOverlaps_OrderingDependency() {
    // Test that the min/max ordering in the overlaps function works correctly
    // This tests cases where the order of comparison might matter
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 7)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_ExactBoundaryOverlap() {
    // Test cases where references touch exactly at boundaries
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_IdenticalRanges() {
    // Test identical ranges
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_EdgeCaseNilHandling() {
    // Test edge cases around nil handling in the overlaps function
    // The function defaults nil verseStart to 1 and nil verseEnd to verseStart
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_CaseSensitiveBookComparison() {
    // Test that book comparison is case-sensitive (as implemented)
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "gen", chapter: 1, verse: 1)
    
    #expect(!ref1.overlaps(with: ref2))
    #expect(!ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_EdgeCaseLargeRanges() {
    // Test with very large verse ranges
    let ref1 = BibleReference(versionId: 1, bookUSFM: "PSA", chapter: 119, verseStart: 1, verseEnd: 176)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "PSA", chapter: 119, verseStart: 80, verseEnd: 120)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_EdgeCaseMinimalOverlap() {
    // Test minimal overlap scenarios
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 100)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 100, verseEnd: 200)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_EdgeCaseZeroLengthRange() {
    // Test edge case where a range has zero length (start == end)
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 5)
    
    #expect(ref1.overlaps(with: ref2))
    #expect(ref2.overlaps(with: ref1))
}

@Test
func testOverlaps_ChapterVsSingleVerse() {
    // Both verseStart and verseEnd nil means whole chapter reference
    let chapter = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let single = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    #expect(chapter.overlaps(with: single))
    #expect(single.overlaps(with: chapter))
}

@Test
func testOverlaps_ChapterVsRange() {
    let chapter = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let range = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    #expect(chapter.overlaps(with: range))
    #expect(range.overlaps(with: chapter))
}

@Test
func testOverlaps_ChapterVsChapter_SameChapter() {
    let chapter1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let chapter2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    #expect(chapter1.overlaps(with: chapter2))
    #expect(chapter2.overlaps(with: chapter1))
}

@Test
func testOverlaps_ChapterVsChapter_DifferentChapter() {
    let chapter1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let chapter2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2)
    #expect(!chapter1.overlaps(with: chapter2))
    #expect(!chapter2.overlaps(with: chapter1))
}

@Test
func testOverlaps_ChapterVsChapterVerseVerse_DifferentChapter() {
    let chapter1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let chapter2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verseStart: 3, verseEnd: 3)
    #expect(!chapter1.overlaps(with: chapter2))
    #expect(!chapter2.overlaps(with: chapter1))
}


