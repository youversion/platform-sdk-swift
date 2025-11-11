@testable import YouVersionPlatformCore
import Testing

// MARK: - Test contains function

@Test
func testContains_SameReference() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
    
    #expect(ref1.contains(with: ref2))
    #expect(ref2.contains(with: ref1))
}

@Test
func testContains_RangeContainsSingleVerse() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 5)
    
    #expect(ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_RangeContainsSmallerRange() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 7)
    
    #expect(ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_RangeContainsRangeAtBoundary() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    
    #expect(ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_RangeContainsRangeAtEndBoundary() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 7, verseEnd: 10)
    
    #expect(ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_OverlappingRangesDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 9)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_AdjacentRangesDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 6, verseEnd: 8)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_SeparateRangesDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 8, verseEnd: 10)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_DifferentChaptersDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 50)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verseStart: 1, verseEnd: 10)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_DifferentBooksDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 50)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 1, verseStart: 1, verseEnd: 10)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_DifferentVersionsDoNotContain() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 50)
    let ref2 = BibleReference(versionId: 2, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10)
    
    #expect(!ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_EdgeCaseSingleVerseRanges() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 5)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 5)
    
    #expect(ref1.contains(with: ref2))
    #expect(ref2.contains(with: ref1))
}

@Test
func testContains_EdgeCaseLargeRanges() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "PSA", chapter: 119, verseStart: 1, verseEnd: 176)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "PSA", chapter: 119, verseStart: 80, verseEnd: 120)
    
    #expect(ref1.contains(with: ref2))
    #expect(!ref2.contains(with: ref1))
}

@Test
func testContains_EdgeCaseNilHandling() {
    // Test edge cases around nil handling in the contains function
    // The function defaults nil verseStart to 1 and nil verseEnd to verseStart
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)
    
    #expect(!ref1.contains(with: ref2))
    #expect(ref2.contains(with: ref1))
}

@Test
func testContains_ChapterContainsSingleVerse() {
    let chapter = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let single = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 10)
    #expect(chapter.contains(with: single))
    #expect(!single.contains(with: chapter))
}

@Test
func testContains_ChapterContainsRange() {
    let chapter = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let range = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    #expect(chapter.contains(with: range))
    #expect(!range.contains(with: chapter))
}

@Test
func testContains_ChapterContainsChapter_SameChapter() {
    let chapter1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let chapter2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    #expect(chapter1.contains(with: chapter2))
    #expect(chapter2.contains(with: chapter1))
}

@Test
func testContains_ChapterDoesNotContainDifferentChapter() {
    let chapter1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
    let chapter2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2)
    #expect(!chapter1.contains(with: chapter2))
    #expect(!chapter2.contains(with: chapter1))
}

@Test
func testContains_ComplexContainmentScenarios() {
    // Test various complex containment scenarios
    let scenarios: [(BibleReference, BibleReference, Bool, Bool)] = [
        // (ref1, ref2, ref1ContainsRef2, ref2ContainsRef1)
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 7), true, false),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 15),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10), false, false),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5), true, true),
        
        (BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5),
         BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5), true, false),
    ]
    
    for (ref1, ref2, ref1ContainsRef2, ref2ContainsRef1) in scenarios {
        #expect(ref1.contains(with: ref2) == ref1ContainsRef2, "Failed for ref1.contains(ref2): ref1: \(ref1), ref2: \(ref2)")
        #expect(ref2.contains(with: ref1) == ref2ContainsRef1, "Failed for ref2.contains(ref1): ref2: \(ref2), ref1: \(ref1)")
    }
}


