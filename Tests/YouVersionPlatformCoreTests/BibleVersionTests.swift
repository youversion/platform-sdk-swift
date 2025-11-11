import Foundation
import Testing
@testable import YouVersionPlatformCore

struct BibleVersionTests {

    private static let version: BibleVersion = {
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

    private static let canonicalUSFMs = Set(version.bookUSFMs)

    @Test
    func decodesCoreMetadata() throws {
        let version = Self.version
        #expect(version.id == 206)
        #expect(version.abbreviation == "engWEBUS")
        #expect(version.localizedAbbreviation == "WEBUS")
        #expect(version.title == "World English Bible, American English Edition, without Strong's Numbers")
        #expect(version.localizedTitle == "World English Bible, American English Edition, without Strong's Numbers")
        #expect(version.languageTag == "en")
        #expect(version.bookUSFMs.count == 80)
        let bookCodes = try #require(version.bookCodes)
        #expect(bookCodes == version.bookUSFMs)
        #expect(bookCodes.first == "GEN")
        #expect(bookCodes.last == "REV")
        #expect(version.copyrightShort == "PUBLIC DOMAIN (not copyrighted)")
        #expect(version.copyrightLong == "This Public Domain Bible text is courtesy of eBible.org.")
    }

    @Test(arguments: [
        ("GEN", true),
        ("gen", true),
        ("jHn", true),
        ("jhn", true),
        ("rev", true),
        ("GAN", false),
        ("REEV", false),
        ("R", false)
    ])
    func bookUSFMValidation(usfm: String, isValid: Bool) {
        let normalized = usfm.uppercased()
        #expect(Self.canonicalUSFMs.contains(normalized) == isValid)
    }

    @Test
    func decodesBooks() throws {
        let books = try #require(Self.version.books)
        #expect(books.count == 80)
        let genesis = try #require(books.first { $0.usfm == "GEN" })
        #expect(genesis.abbreviation == "Gen")
        #expect(genesis.title == "Genesis")
        let revelation = try #require(books.first { $0.usfm == "REV" })
        #expect(revelation.abbreviation == "Rev")
        #expect(revelation.chapters?.last?.title == "22")
    }

    @Test(arguments: [
        ("GEN", "Genesis", "Gen", 50, "GEN.1"),
        ("PSA", "Psalms", "Psa", 150, "PSA.1"),
        ("REV", "Revelation", "Rev", 22, "REV.1")
    ])
    func bookMetadata(
        bookUSFM: String,
        expectedTitle: String,
        expectedAbbreviation: String,
        expectedChapterCount: Int,
        expectedFirstChapterId: String
    ) throws {
        let book = try #require(Self.version.book(with: bookUSFM))
        #expect(book.title == expectedTitle)
        #expect(book.abbreviation == expectedAbbreviation)
        let chapters = try #require(book.chapters)
        #expect(chapters.count == expectedChapterCount)
        #expect(chapters.first?.passageId == expectedFirstChapterId)
        let labels = Self.version.chapterLabels(bookUSFM)
        #expect(labels.count == expectedChapterCount)
        #expect(labels.first == "1")
        #expect(labels.last == String(expectedChapterCount))
    }

    @Test
    func referenceTrimsWhitespace() throws {
        let reference = try #require(Self.version.reference(with: "  GEN.1.5  "))
        #expect(reference.bookUSFM == "GEN")
        #expect(reference.chapter == 1)
        #expect(reference.verseStart == 5)
    }

    @Test
    func referenceMergesAdjacentVersesSeparatedByPlus() throws {
        let reference = try #require(Self.version.reference(with: "GEN.1.1+GEN.1.2"))
        #expect(reference.bookUSFM == "GEN")
        #expect(reference.chapter == 1)
        #expect(reference.verseStart == 1)
        #expect(reference.verseEnd == 2)
    }

    @Test
    func referenceSkipsInvalidSegments() throws {
        let reference = try #require(Self.version.reference(with: "GEN.3.7+GAN.3.8+GEN.3.8"))
        #expect(reference.bookUSFM == "GEN")
        #expect(reference.chapter == 3)
        #expect(reference.verseStart == 7)
        #expect(reference.verseEnd == 8)
    }

    @Test
    func referenceReturnsNilWhenAllSegmentsInvalid() {
        #expect(Self.version.reference(with: "GAN.1.1+GAN.1.2") == nil)
    }

}
