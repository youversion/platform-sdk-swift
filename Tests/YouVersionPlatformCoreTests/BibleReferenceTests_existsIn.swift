import Foundation
import Testing
@testable import YouVersionPlatformCore

struct BibleReferenceExistsInTests {

    private static let fixtureVersion: BibleVersion = {
        guard let url = Bundle.module.url(forResource: "bible_206", withExtension: "json") else {
            fatalError("Missing bible_206.json fixture in test bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BibleVersion.self, from: data)
        } catch {
            fatalError("Failed to decode bible_206.json: \(error)")
        }
    }()

    @Test
    func existsInReturnsTrueWhenBookAndChapterArePresent() {
        let reference = BibleReference(versionId: 206, bookUSFM: "GEN", chapter: 1, verse: 1)

        #expect(reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInReturnsTrueForChapterOnlyReferenceWhenChapterIsPresent() {
        let reference = BibleReference(versionId: 206, bookUSFM: "GEN", chapter: 1)

        #expect(reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInReturnsFalseForChapterOnlyReferenceWhenBookIsMissing() {
        let reference = BibleReference(versionId: 206, bookUSFM: "ABC", chapter: 1)

        #expect(!reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInReturnsFalseForChapterOnlyReferenceWhenChapterIsMissing() {
        let reference = BibleReference(versionId: 206, bookUSFM: "GEN", chapter: 51)

        #expect(!reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInReturnsFalseWhenBookIsMissing() {
        let reference = BibleReference(versionId: 206, bookUSFM: "ABC", chapter: 1, verse: 1)

        #expect(!reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInReturnsFalseWhenChapterIsMissing() {
        let reference = BibleReference(versionId: 206, bookUSFM: "GEN", chapter: 51, verse: 1)

        #expect(!reference.existsIn(version: Self.fixtureVersion))
    }

    @Test
    func existsInTreatsMissingChapterMetadataAsAvailable() {
        let version = BibleVersion(
            id: 206,
            abbreviation: "TEST",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "TEST",
            localizedTitle: "Test Version",
            readerFooter: nil,
            readerFooterUrl: nil,
            title: "Test Version",
            organizationId: nil,
            bookCodes: ["GEN"],
            books: nil,
            textDirection: "ltr"
        )
        let reference = BibleReference(versionId: 206, bookUSFM: "GEN", chapter: 99, verse: 1)

        #expect(reference.existsIn(version: version))
    }
}
