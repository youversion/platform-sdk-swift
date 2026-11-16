import Foundation
import Testing
@testable import YouVersionPlatformCore

struct NotePassageTests {
    private func verse(_ number: Int) -> BibleReference {
        BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: number)
    }

    @Test
    func nonconsecutiveSelectionRoundTripsThroughJSONWithoutAddingVerses() throws {
        let references = [verse(1), verse(3), verse(5)]
        let passage = try NotePassage(references: references)
        #expect(passage.references == references)
        let data = try JSONEncoder().encode(passage)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.count == 2)
        #expect(json["bible_id"] as? Int == 3034)
        #expect(json["passage_id"] as? String == "GEN.1.1+GEN.1.3+GEN.1.5")
        let decoded = try JSONDecoder().decode(NotePassage.self, from: data)
        #expect(decoded.references == references)
    }

    @Test
    func constructionSortsAndMergesOnlyAdjacentOrOverlappingVerses() throws {
        let references = [verse(6), verse(4), verse(1), verse(3), verse(3)]
        let passage = try NotePassage(references: references)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(passage)) as? [String: Any])
        #expect(json["passage_id"] as? String == "GEN.1.1+GEN.1.3-4+GEN.1.6")
        #expect(passage.references == [
            verse(1),
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verseStart: 3, verseEnd: 4),
            verse(6)
        ])
    }

    @Test
    func compactRangesParseWithTheAttachedBibleVersion() throws {
        let passage = try JSONDecoder().decode(NotePassage.self, from: Data(#"{"bible_id":111,"passage_id":"1JN.2.1-3+1JN.2.5"}"#.utf8))
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
        #expect(throws: YouVersionAPIRequestError.self) { try NotePassage(references: []) }
        for reference in incompatible {
            #expect(throws: YouVersionAPIRequestError.self) { try NotePassage(references: [verse(1), reference]) }
        }
    }

    @Test(arguments: [
        "", "GEN.1", "GEN.0.1", "GEN.1.0", "GEN.1.5-3", "GEN.1.1+", "+GEN.1.1",
        "GEN.1.1++GEN.1.3", "GEN.1.1+bad", "GEN.1.1+GEN.2.3", "GEN.1.1+EXO.1.3",
        "gen.1.1", "GEN.1.1-GEN.2.3", "GEN.1.99999999999999999999999999999999"
    ])
    func malformedOrUnsupportedStringsNeverReturnAPartialSelection(passageID: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["bible_id": 3034, "passage_id": passageID])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(NotePassage.self, from: data) }
    }
}
