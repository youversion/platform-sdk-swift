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
    func matchesStraightApostropheTermAgainstTypographicText() {
        let h = BibleTermHighlight(ref(1), term: "Queen Esther's", color: "#FFCC00", id: "25")
        let text = "So the king and Haman went to dine with Queen Esther\u{2019}s banquet"
        let range = h.firstMatchRange(in: text)
        #expect(range != nil)
        #expect(range.map { String(text[$0]) } == "Queen Esther\u{2019}s")
    }

    @Test
    func matchesTermEndingInApostrophe() {
        let h = BibleTermHighlight(ref(7), term: "lions'", color: "#FFCC00", id: "45")
        let text = "shall be cast into the lions\u{2019} den"
        let range = h.firstMatchRange(in: text)
        #expect(range != nil)
        #expect(range.map { String(text[$0]) } == "lions\u{2019}")
    }

    @Test
    func matchesTypographicTermAgainstStraightText() {
        // The fold works in both directions, whichever form each source uses.
        let h = BibleTermHighlight(ref(7), term: "lions\u{2019}", color: "#FFCC00", id: "45")
        let text = "shall be cast into the lions' den"
        #expect(h.firstMatchRange(in: text).map { String(text[$0]) } == "lions'")
    }

    @Test
    func returnedRangeIndexesOriginalText() {
        // The renderer maps this range to offsets in the very string passed in, so the
        // range must slice back to the matched term without drift.
        let h = BibleTermHighlight(ref(1), term: "Queen Esther's", color: "#FFCC00", id: "25")
        let text = "dine with Queen Esther\u{2019}s banquet today"
        let range = h.firstMatchRange(in: text)
        #expect(range != nil)
        guard let range else {
            return
        }
        #expect(text.distance(from: text.startIndex, to: range.lowerBound) == 10)
        #expect(String(text[range]) == "Queen Esther\u{2019}s")
    }

    @Test
    func quoteFoldingStillRespectsWordBoundaries() {
        // Folding must not loosen the whole-word rule.
        let h = BibleTermHighlight(ref(7), term: "son's", color: "#FFCC00", id: "1")
        #expect(h.firstMatchRange(in: "the person\u{2019}s cloak") == nil)
        let text = "her son\u{2019}s cloak"
        #expect(h.firstMatchRange(in: text).map { String(text[$0]) } == "son\u{2019}s")
    }

    @Test
    func preservesUnicodeCaseFoldingAcrossDifferingCharacterCounts() {
        // Quote folding must not regress Foundation's full case folding, where one
        // grapheme folds to several characters.
        let sharpS = BibleTermHighlight(ref(1), term: "stra\u{00DF}e", color: "#FFCC00", id: "9")
        #expect(sharpS.firstMatchRange(in: "the STRASSE gate") != nil)
        let ligature = BibleTermHighlight(ref(1), term: "FISH", color: "#FFCC00", id: "10")
        #expect(ligature.firstMatchRange(in: "a \u{FB01}sh and bread") != nil)
    }

    @Test
    func matchesCurlyDoubleQuotes() {
        let h = BibleTermHighlight(ref(1), term: "\"Immanuel\"", color: "#FFCC00", id: "3")
        let text = "they shall call his name \u{201C}Immanuel\u{201D} among them"
        #expect(h.firstMatchRange(in: text).map { String(text[$0]) } == "\u{201C}Immanuel\u{201D}")
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
