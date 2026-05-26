import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@Suite struct BibleVersionDisplayTitleTests {
    @Test func displayTitleFallsBackToBookUSFMForInvalidBook() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "XYZ", chapter: 3)

        #expect(version.displayTitle(for: reference) == "XYZ 3 NIV")
    }

    @Test func displayTitleUsesBookNameAndChapterForWholeChapterReference() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1)

        #expect(version.displayTitle(for: reference) == "Genesis 1 NIV")
    }

    @Test func displayTitleUsesBookNameAndChapterForWholeChapterVerseSentinel() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 999)

        #expect(version.displayTitle(for: reference) == "Genesis 1 NIV")
    }

    @Test func displayTitleOmitsChapterForWholeChapterSingleChapterBook() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "JUD", chapter: 1)

        #expect(version.displayTitle(for: reference) == "Jude NIV")
    }

    @Test func displayTitleOmitsChapterForWholeChapterSentinelInSingleChapterBook() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "JUD", chapter: 1, verseStart: 1, verseEnd: 999)

        #expect(version.displayTitle(for: reference) == "Jude NIV")
    }

    @Test func displayTitleIncludesSingleVerse() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 3)

        #expect(version.displayTitle(for: reference) == "Genesis 1:3 NIV")
    }

    @Test func displayTitleIncludesVerseRange() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verseStart: 3, verseEnd: 5)

        #expect(version.displayTitle(for: reference) == "Genesis 1:3-5 NIV")
    }

    @Test func displayTitleIncludesSingleVerseInSingleChapterBook() {
        let version = makeBibleVersion()
        let reference = BibleReference(versionId: 111, bookUSFM: "JUD", chapter: 1, verse: 4)

        #expect(version.displayTitle(for: reference) == "Jude 4 NIV")
    }

    private func makeBibleVersion() -> BibleVersion {
        BibleVersion(
            id: 111,
            abbreviation: "NIV",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "eng",
            localizedAbbreviation: nil,
            localizedTitle: nil,
            readerFooter: nil,
            readerFooterUrl: nil,
            title: nil,
            organizationId: nil,
            bookCodes: nil,
            books: [
                makeBibleBook(id: "GEN", title: "Genesis", chapterCount: 50),
                makeBibleBook(id: "JUD", title: "Jude", chapterCount: 1)
            ],
            textDirection: "ltr"
        )
    }

    private func makeBibleBook(id: String, title: String, chapterCount: Int) -> BibleBook {
        BibleBook(
            id: id,
            title: title,
            fullTitle: title,
            abbreviation: nil,
            canon: "nt",
            chapters: (1...chapterCount).map { chapter in
                BibleChapter(id: String(chapter), passageId: "\(id).\(chapter)", title: String(chapter), verses: nil)
            },
            intro: nil
        )
    }
}
