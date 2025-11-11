@testable import YouVersionPlatformCore
import Testing

@MainActor
struct BibleHighlightsCacheTests {

    @Test
    func testHighlightsEmptyState() {
        let cache = BibleHighlightsCache()
        #expect(cache.highlights(overlapping: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)).isEmpty)
    }

    // MARK: - Test Basic CRUD Operations

    @Test
    func testHighlightsAdd() {
        let cache = BibleHighlightsCache()
        let highlight = BibleHighlight(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1), color: "eefeef")

        cache.addHighlights([highlight])

        let highlights = cache.highlights(overlapping: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1))

        #expect(highlights.count == 1)
        #expect(highlights.first?.reference.versionId == 1)
        #expect(highlights.first?.reference.bookUSFM == "GEN")
        #expect(highlights.first?.reference.chapter == 1)
        #expect(highlights.first?.reference.verseStart == 1)
        #expect(highlights.first?.color == "eefeef")
    }

    @Test
    func testHighlightsRemove() {
        let cache = BibleHighlightsCache()
        let highlight = BibleHighlight(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1), color: "eefeef")

        cache.addHighlights([highlight])
        cache.removeHighlights([BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)])

        let highlights = cache.highlights(overlapping: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1))

        #expect(highlights.isEmpty)
    }

    @Test
    func testHighlightsUpdateColors() {
        let cache = BibleHighlightsCache()
        let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let highlight = BibleHighlight(ref, color: "eefeef")

        cache.addHighlights([highlight])
        cache.updateHighlightColors([ref], newColor: "0000ff")

        let highlights = cache.highlights(overlapping: ref)

        #expect(highlights.count == 1)
        #expect(highlights.first?.color == "0000ff")
    }

    // MARK: - Test Range Queries

    @Test
    func testHighlightsGetRange() {
        let cache = BibleHighlightsCache()
        let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        let ref3 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 3)
        let highlight1 = BibleHighlight(ref1, color: "eefeef")
        let highlight2 = BibleHighlight(ref2, color: "0000ff")
        let highlight3 = BibleHighlight(ref3, color: "00ffff")

        cache.addHighlights([highlight1, highlight2, highlight3])

        let highlights = cache.highlights(overlapping: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 3))

        #expect(highlights.count == 3)
        #expect(highlights.contains { $0.reference.verseStart == 1 })
        #expect(highlights.contains { $0.reference.verseStart == 2 })
        #expect(highlights.contains { $0.reference.verseStart == 3 })
    }

    @Test
    func testHighlightsGetCrossChapter() {
        let cache = BibleHighlightsCache()
        let ref1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let ref2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2, verse: 1)
        let highlight1 = BibleHighlight(ref1, color: "eefeef")
        let highlight2 = BibleHighlight(ref2, color: "0000ff")

        cache.addHighlights([highlight1, highlight2])

        // Test that we only get highlights from chapter 1 when querying chapter 1
        let highlights = cache.highlights(overlapping: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 1))

        #expect(highlights.count == 1)
        #expect(highlights.contains { $0.reference.chapter == 1 && $0.reference.verseStart == 1 })
        #expect(!highlights.contains { $0.reference.chapter == 2 && $0.reference.verseStart == 1 })
    }

    // MARK: - Test Server Merge

    @Test
    func testApplyServerHighlights() {
        let cache = BibleHighlightsCache()
        let chapter = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
        let server = [
            BibleHighlight(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1), color: "#ff0000")
        ]

        cache.applyServerHighlights(for: chapter, highlights: server)

        let highlights = cache.highlights(overlapping: chapter)
        #expect(highlights.count == 1)
        #expect(highlights.first?.color == "#ff0000")
    }
}
