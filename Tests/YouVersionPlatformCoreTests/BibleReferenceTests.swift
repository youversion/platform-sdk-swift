@testable import YouVersionPlatformCore
import Testing

// MARK: - Test Initialization

@Test
func testInitSingleVerse() {
    let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 3)

    #expect(ref.versionId == 1)
    #expect(ref.bookUSFM == "GEN")
    #expect(ref.chapter == 2)
    #expect(ref.verseStart == 3)
    #expect(ref.verseEnd == 3)
}

@Test
func testInitVerseRange() {
    let ref = BibleReference(versionId: 1, bookUSFM: "PSA", chapter: 23, verseStart: 1, verseEnd: 2)
    
    #expect(ref.versionId == 1)
    #expect(ref.bookUSFM == "PSA")
    #expect(ref.chapter == 23)
    #expect(ref.verseStart == 1)
    #expect(ref.verseEnd == 2)
}

// MARK: - Test isRange

@Test
func testIsRange_SingleVerse() {
    let ref = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 3, verse: 14)
    #expect(!ref.isRange)
}

@Test
func testIsRange_VerseRange() {
    let ref = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 3, verseStart: 14, verseEnd: 15)
    #expect(ref.isRange)
}

// MARK: - Test compare function

@Test
func testCompare_SameReference() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    
    #expect(ref1 == ref2)
}

@Test
func testCompare_DifferentBooks() {
    // Note: Comparing different books is not reliable without knowing the canonical book order
    // This test just verifies the function doesn't crash with different book usfms
    let genRef = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let exoRef = BibleReference(versionId: 1, bookUSFM: "EXO", chapter: 1, verse: 1)
    
    // Just verify the function can be called with different books
    // The actual comparison result is not validated
    _ = BibleReference.compare(a: genRef, b: exoRef)
    _ = BibleReference.compare(a: exoRef, b: genRef)
    
    // This test passes as long as the above lines don't crash
}

@Test
func testCompare_SameBookDifferentChapters() {
    let gen1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let gen2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 1)
    
    #expect(gen1 < gen2)
    #expect(BibleReference.compare(a: gen1, b: gen2) == -1) // GEN 1 < GEN 2
    #expect(BibleReference.compare(a: gen2, b: gen1) == 1)  // GEN 2 > GEN 1
}

@Test
func testCompare_SameChapterDifferentVerses() {
    let gen1_1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
    let gen1_2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
    
    #expect(gen1_1 < gen1_2)
    #expect(gen1_2 > gen1_1)
}

@Test
func testCompare_Ranges() {
    let gen1_1to3 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3)
    let gen1_2to4 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 2, verseEnd: 4)
    
    // Compare based on starting verse first
    #expect(gen1_1to3 < gen1_2to4)
    
    // Same starting verse, compare end verse
    let gen1_1to3_2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3)
    let gen1_1to4 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 4)
    
    #expect(gen1_1to3_2 < gen1_1to4)    // 1-3 < 1-4
}

@Test
func testSorting() {
    let refs = [
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 4, verse: 3),
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 3, verse: 2),
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 1),
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
    ]
    
    let sorted = refs.sorted()
    
    #expect(sorted[0].bookUSFM == "GEN")
    #expect(sorted[0].chapter == 1)
    #expect(sorted[0].verseStart == 1)
    
    #expect(sorted[1].bookUSFM == "GEN")
    #expect(sorted[1].chapter == 1)
    #expect(sorted[1].verseStart == 2)
    
    #expect(sorted[2].bookUSFM == "GEN")
    #expect(sorted[2].chapter == 2)
    #expect(sorted[2].verseStart == 1)
    
    #expect(sorted[3].bookUSFM == "GEN")
    #expect(sorted[3].chapter == 3)
    #expect(sorted[3].verseStart == 2)
    
    #expect(sorted[4].bookUSFM == "GEN")
    #expect(sorted[4].chapter == 4)
    #expect(sorted[4].verseStart == 3)
}

// MARK: - Test chapterUSFM

@Test
func testChapterUSFM() {
    let ref = BibleReference(versionId: 1, bookUSFM: "gen", chapter: 1, verse: 1)
    #expect(ref.chapterUSFM == "GEN.1")
}

// MARK: - Test asUSFM

@Test
func testAsUSFM() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "gen", chapter: 1)
    #expect(ref1.asUSFM == "GEN.1")

    let ref2 = BibleReference(versionId: 1, bookUSFM: "gen", chapter: 1, verse: 1)
    #expect(ref2.asUSFM == "GEN.1.1")

    let ref3 = BibleReference(versionId: 1, bookUSFM: "gen", chapter: 1, verseStart: 1, verseEnd: 5)
    #expect(ref3.asUSFM == "GEN.1.1-GEN.1.5")
}

// MARK: - Test Merging references

@Test
func testMerge_adjacentReferences() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 4, verseEnd: 6)
    
    let merged1To2 = BibleReference.referenceByMerging(a: ref1, b: ref2)
    #expect(merged1To2.versionId == 1)
    #expect(merged1To2.bookUSFM == "GEN")
    #expect(merged1To2.chapter == 1)
    #expect(merged1To2.verseStart == 1)
    #expect(merged1To2.verseEnd == 6)
    
    // show that order does not matter
    let merged2To1 = BibleReference.referenceByMerging(a: ref2, b: ref1)
    #expect(merged2To1.versionId == 1)
    #expect(merged2To1.bookUSFM == "GEN")
    #expect(merged2To1.chapter == 1)
    #expect(merged2To1.verseStart == 1)
    #expect(merged2To1.verseEnd == 6)
}

@Test
func testMerge_overlappingReferences() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 7)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 9)
    
    let merged1To2 = BibleReference.referenceByMerging(a: ref1, b: ref2)
    #expect(merged1To2.versionId == 1)
    #expect(merged1To2.bookUSFM == "GEN")
    #expect(merged1To2.chapter == 1)
    #expect(merged1To2.verseStart == 3)
    #expect(merged1To2.verseEnd == 9)
    
    // show that order does not matter
    let merged2To1 = BibleReference.referenceByMerging(a: ref2, b: ref1)
    #expect(merged2To1.versionId == 1)
    #expect(merged2To1.bookUSFM == "GEN")
    #expect(merged2To1.chapter == 1)
    #expect(merged2To1.verseStart == 3)
    #expect(merged2To1.verseEnd == 9)
}

@Test
func testMerge_oneReferenceContainsAnother() {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 2, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 7)
    
    let merged1To2 = BibleReference.referenceByMerging(a: ref1, b: ref2)
    #expect(merged1To2.versionId == 1)
    #expect(merged1To2.bookUSFM == "GEN")
    #expect(merged1To2.chapter == 1)
    #expect(merged1To2.verseStart == 2)
    #expect(merged1To2.verseEnd == 10)
    
    // show that order does not matter
    let merged2To1 = BibleReference.referenceByMerging(a: ref2, b: ref1)
    #expect(merged2To1.versionId == 1)
    #expect(merged2To1.bookUSFM == "GEN")
    #expect(merged2To1.chapter == 1)
    #expect(merged2To1.verseStart == 2)
    #expect(merged2To1.verseEnd == 10)
}

@Test
func mergeMultipleGroupsOfReferences() throws {
    let ref1 = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 4, verseStart: 2, verseEnd: 10)
    let ref2 = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 2, verseStart: 5, verseEnd: 7)
    let ref3 = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 4, verseStart: 5, verseEnd: 12)
    let ref4 = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 2, verseStart: 8, verseEnd: 11)
    let ref5 = BibleReference(versionId: 1, bookUSFM: "JHN", chapter: 1, verseStart: 5, verseEnd: 7)
    
    let result = BibleReference.referencesByMerging(references: [ref1, ref2, ref3, ref4, ref5])
    #expect(result.count == 3)
    
    let singleChapter1 = try #require(result.first { $0.chapter == 1 })
    #expect(singleChapter1.chapter == 1)
    #expect(singleChapter1.verseStart == 5)
    #expect(singleChapter1.verseEnd == 7)
    
    let mergedChapter2 = try #require(result.first { $0.chapter == 2 })
    #expect(mergedChapter2.chapter == 2)
    #expect(mergedChapter2.verseStart == 5)
    #expect(mergedChapter2.verseEnd == 11)
    
    let mergedChapter4 = try #require(result.first { $0.chapter == 4 })
    #expect(mergedChapter4.chapter == 4)
    #expect(mergedChapter4.verseStart == 2)
    #expect(mergedChapter4.verseEnd == 12)
}
