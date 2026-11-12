import Foundation
import Testing
import YouVersionPlatformCore

struct YouVersionNotePassageTests {
    private func verse(_ number: Int) -> BibleReference {
        BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: number)
    }

    @Test
    func nonconsecutiveSelectionRoundTripsThroughJSONWithoutAddingVerses() throws {
        let references = [verse(1), verse(3), verse(5)]
        let passage = try #require(YouVersionNote.Passage(references: references))
        #expect(passage.passageID == "GEN.1.1+GEN.1.3+GEN.1.5")
        #expect(passage.references == references)
        let data = try JSONEncoder().encode(passage)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.count == 2)
        #expect(json["bible_id"] as? Int == 3034)
        #expect(json["passage_id"] as? String == passage.passageID)
        let decoded = try JSONDecoder().decode(YouVersionNote.Passage.self, from: data)
        #expect(decoded.references == references)
    }

    @Test
    func constructionSortsAndMergesOnlyAdjacentOrOverlappingVerses() throws {
        let references = [verse(6), verse(4), verse(1), verse(3), verse(3)]
        let passage = try #require(YouVersionNote.Passage(references: references))
        #expect(passage.passageID == "GEN.1.1+GEN.1.3-4+GEN.1.6")
        #expect(passage.references == [
            verse(1),
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verseStart: 3, verseEnd: 4),
            verse(6)
        ])
    }

    @Test
    func compactRangesParseWithTheAttachedBibleVersion() throws {
        let passage = YouVersionNote.Passage(bibleID: 111, passageID: "1JN.2.1-3+1JN.2.5")
        #expect(passage.references == [
            BibleReference(versionId: 111, bookId: "1JN", chapter: 2, verseStart: 1, verseEnd: 3),
            BibleReference(versionId: 111, bookId: "1JN", chapter: 2, verse: 5)
        ])
    }

    @Test
    func incompatibleReferencesDoNotCreateAnAttachment() {
        let incompatible = [
            BibleReference(versionId: 111, bookId: "GEN", chapter: 1, verse: 3),
            BibleReference(versionId: 3034, bookId: "EXO", chapter: 1, verse: 3),
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 2, verse: 3),
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 1)
        ]
        #expect(YouVersionNote.Passage(references: []) == nil)
        for reference in incompatible {
            #expect(YouVersionNote.Passage(references: [verse(1), reference]) == nil)
        }
    }

    @Test(arguments: [
        "", "GEN.1", "GEN.0.1", "GEN.1.0", "GEN.1.5-3", "GEN.1.1+", "+GEN.1.1",
        "GEN.1.1++GEN.1.3", "GEN.1.1+bad", "GEN.1.1+GEN.2.3", "GEN.1.1+EXO.1.3",
        "gen.1.1", "GEN.1.1-GEN.2.3", "GEN.1.99999999999999999999999999999999"
    ])
    func malformedOrUnsupportedStringsNeverReturnAPartialSelection(passageID: String) {
        let passage = YouVersionNote.Passage(bibleID: 3034, passageID: passageID)
        #expect(passage.references == nil)
    }
}
