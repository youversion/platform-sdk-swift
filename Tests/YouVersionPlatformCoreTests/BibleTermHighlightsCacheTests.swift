@testable import YouVersionPlatformCore
import Testing

@MainActor
struct BibleTermHighlightsCacheTests {

    private func ref(_ verse: Int, chapter: Int = 1, book: String = "LUK", version: Int = 111) -> BibleReference {
        BibleReference(versionId: version, bookUSFM: book, chapter: chapter, verse: verse)
    }

    @Test
    func emptyState() {
        let cache = BibleTermHighlightsCache()
        #expect(cache.termHighlights(overlapping: ref(1, chapter: 1)).isEmpty)
    }

    @Test
    func addAndQueryOverlapping() {
        let cache = BibleTermHighlightsCache()
        cache.addTermHighlights([
            BibleTermHighlight(ref(26), term: "Nazareth", color: "#FFCC00", id: "5")
        ])
        let chapter = BibleReference(versionId: 111, bookUSFM: "LUK", chapter: 1)
        let matches = cache.termHighlights(overlapping: chapter)
        #expect(matches.count == 1)
        #expect(matches.first?.id == "5")
        #expect(matches.first?.term == "Nazareth")
    }

    @Test
    func addReplacesSameID() {
        let cache = BibleTermHighlightsCache()
        cache.addTermHighlights([BibleTermHighlight(ref(26), term: "Nazareth", color: "#FFCC00", id: "5")])
        cache.addTermHighlights([BibleTermHighlight(ref(26), term: "Galilee", color: "#00CCFF", id: "5")])
        let matches = cache.termHighlights(overlapping: BibleReference(versionId: 111, bookUSFM: "LUK", chapter: 1))
        #expect(matches.count == 1)
        #expect(matches.first?.term == "Galilee")
    }

    @Test
    func removeByID() {
        let cache = BibleTermHighlightsCache()
        cache.addTermHighlights([
            BibleTermHighlight(ref(26), term: "Nazareth", color: "#FFCC00", id: "5"),
            BibleTermHighlight(ref(26), term: "Mary", color: "#FFCC00", id: "6")
        ])
        cache.removeTermHighlights(ids: ["5"])
        let matches = cache.termHighlights(overlapping: BibleReference(versionId: 111, bookUSFM: "LUK", chapter: 1))
        #expect(matches.count == 1)
        #expect(matches.first?.id == "6")
    }

    @Test
    func setReplacesAll() {
        let cache = BibleTermHighlightsCache()
        cache.addTermHighlights([BibleTermHighlight(ref(26), term: "Nazareth", color: "#FFCC00", id: "5")])
        cache.setTermHighlights([BibleTermHighlight(ref(31), term: "son", color: "#FFCC00", id: "1")])
        let matches = cache.termHighlights(overlapping: BibleReference(versionId: 111, bookUSFM: "LUK", chapter: 1))
        #expect(matches.count == 1)
        #expect(matches.first?.id == "1")
    }

    // MARK: - Term matching

    @Test
    func matchesSingleWordCaseInsensitive() {
        let h = BibleTermHighlight(ref(26), term: "nazareth", color: "#FFCC00", id: "5")
        let text = "God sent the angel Gabriel to Nazareth, a town in Galilee"
        let range = h.firstMatchRange(in: text)
        #expect(range != nil)
        #expect(range.map { String(text[$0]) } == "Nazareth")
    }

    @Test
    func matchesMultiWordTerm() {
        let h = BibleTermHighlight(
            BibleReference(versionId: 111, bookUSFM: "MAT", chapter: 4, verse: 18),
            term: "Sea of Galilee",
            color: "#FFCC00",
            id: "2"
        )
        let text = "As Jesus was walking beside the Sea of Galilee, he saw two brothers"
        #expect(h.firstMatchRange(in: text).map { String(text[$0]) } == "Sea of Galilee")
    }

    @Test
    func matchesWholeWordsOnly() {
        // "son" must not match inside "person"; it should match the standalone word.
        let h = BibleTermHighlight(ref(7), term: "son", color: "#FFCC00", id: "1")
        let text = "No person here, but she gave birth to a son in Bethlehem"
        let range = h.firstMatchRange(in: text)
        #expect(range != nil)
        #expect(range.map { String(text[$0]) } == "son")
        // Only present as a substring → no whole-word match.
        #expect(h.firstMatchRange(in: "There were many persons and reasons") == nil)
    }

    @Test
    func noMatchWhenAbsent() {
        let h = BibleTermHighlight(ref(26), term: "Bethlehem", color: "#FFCC00", id: "5")
        #expect(h.firstMatchRange(in: "God sent the angel Gabriel to Nazareth") == nil)
    }

    @Test
    func emptyTermNeverMatches() {
        let h = BibleTermHighlight(ref(26), term: "", color: "#FFCC00", id: "5")
        #expect(h.firstMatchRange(in: "anything") == nil)
    }

    @Test
    func appliesToMatchesVersionBookChapterAndVerse() {
        let h = BibleTermHighlight(ref(26), term: "Nazareth", color: "#FFCC00", id: "5")
        #expect(h.appliesTo(verse: ref(26)))
        #expect(!h.appliesTo(verse: ref(27)))
        #expect(!h.appliesTo(verse: ref(26, chapter: 2)))
        // Same chapter+verse in a different book or version must not match.
        #expect(!h.appliesTo(verse: ref(26, book: "GEN")))
        #expect(!h.appliesTo(verse: ref(26, version: 1)))
    }
}
