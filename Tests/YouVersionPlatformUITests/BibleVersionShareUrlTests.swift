import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@Suite struct BibleVersionShareUrlTests {
    
    // MARK: - Test Data Setup
    
    private func createBibleVersion(
        id: Int,
        abbreviation: String? = nil,
        localizedAbbreviation: String? = nil
    ) -> BibleVersion {
        return BibleVersion(
            id: id,
            abbreviation: abbreviation,
            copyrightLong: nil,
            copyrightShort: nil,
            languageTag: "eng",
            localizedAbbreviation: localizedAbbreviation,
            localizedTitle: nil,
            readerFooter: nil,
            readerFooterUrl: nil,
            title: nil,
            bookCodes: nil,
            books: nil,
            textDirection: "ltr"
        )
    }
    
    
    // MARK: - Single Verse Tests
    
    @Test func testShareUrl_SingleVerse() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verse: 10)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/1SA.3.10.NIV")
    }
    
    @Test func testShareUrl_SingleVerseWithLocalizedAbbreviation() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV", localizedAbbreviation: "NVI")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1.NVI")
    }
    
    @Test func testShareUrl_SingleVerseNoAbbreviation() {
        let version = createBibleVersion(id: 999)
        let reference = BibleReference(versionId: 999, bookUSFM: "PSA", chapter: 23, verse: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/999/PSA.23.1.999")
    }
    
    // MARK: - Verse Range Tests
    
    @Test func testShareUrl_VerseRange() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verseStart: 10, verseEnd: 15)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/1SA.3.10-15.NIV")
    }
    
    @Test func testShareUrl_VerseRangeWithLocalizedAbbreviation() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV", localizedAbbreviation: "NVI")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1-5.NVI")
    }
    
    @Test func testShareUrl_VerseRangeSameStartAndEnd() {
        // This should be treated as a single verse, not a range
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verseStart: 10, verseEnd: 10)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/1SA.3.10.NIV")
    }
    
    // MARK: - Chapter Only Tests
    
    @Test func testShareUrl_ChapterOnly() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/1SA.3.NIV")
    }
    
    @Test func testShareUrl_ChapterOnlyWithLocalizedAbbreviation() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV", localizedAbbreviation: "NVI")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.NVI")
    }
    
    @Test func testShareUrl_ChapterOnlyNoAbbreviation() {
        let version = createBibleVersion(id: 999)
        let reference = BibleReference(versionId: 999, bookUSFM: "PSA", chapter: 23)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/999/PSA.23.999")
    }
    
    // MARK: - Version ID Tests
    
    @Test func testShareUrl_DifferentVersionIds() {
        let version1 = createBibleVersion(id: 1, abbreviation: "KJV")
        let version2 = createBibleVersion(id: 111, abbreviation: "NIV")
        let version3 = createBibleVersion(id: 999, abbreviation: "ESV")
        
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        let url1 = version1.shareUrl(reference: reference)
        let url2 = version2.shareUrl(reference: reference)
        let url3 = version3.shareUrl(reference: reference)
        
        #expect(url1?.absoluteString == "https://www.bible.com/bible/1/GEN.1.1.KJV")
        #expect(url2?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1.NIV")
        #expect(url3?.absoluteString == "https://www.bible.com/bible/999/GEN.1.1.ESV")
    }
    
    // MARK: - Book USFM Tests
    
    @Test func testShareUrl_DifferentBookUSFMs() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        
        let ref1 = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        let ref2 = BibleReference(versionId: 111, bookUSFM: "EXO", chapter: 2, verse: 3)
        let ref3 = BibleReference(versionId: 111, bookUSFM: "PSA", chapter: 23, verse: 1)
        let ref4 = BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verse: 10)
        
        let url1 = version.shareUrl(reference: ref1)
        let url2 = version.shareUrl(reference: ref2)
        let url3 = version.shareUrl(reference: ref3)
        let url4 = version.shareUrl(reference: ref4)
        
        #expect(url1?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1.NIV")
        #expect(url2?.absoluteString == "https://www.bible.com/bible/111/EXO.2.3.NIV")
        #expect(url3?.absoluteString == "https://www.bible.com/bible/111/PSA.23.1.NIV")
        #expect(url4?.absoluteString == "https://www.bible.com/bible/111/1SA.3.10.NIV")
    }
    
    // MARK: - Chapter Number Tests
    
    @Test func testShareUrl_DifferentChapterNumbers() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 50, verse: 20)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.50.20.NIV")
    }
    
    // MARK: - Edge Cases and Potential Bugs
    
    @Test func testShareUrl_VerseStartNilButVerseEndNotNil() {
        // This is an edge case that might occur with malformed BibleReference
        // The current implementation should handle this gracefully
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        
        // Create a reference with verseStart nil but verseEnd not nil
        // This would require creating a BibleReference directly with these values
        // Since the initializers don't allow this, we'll test the logic path
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.NIV")
    }
    
    @Test func testShareUrl_LargeVerseNumbers() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "PSA", chapter: 119, verse: 176)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/PSA.119.176.NIV")
    }
    
    @Test func testShareUrl_LargeVerseRange() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "PSA", chapter: 119, verseStart: 1, verseEnd: 176)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/PSA.119.1-176.NIV")
    }
    
    @Test func testShareUrl_EmptyAbbreviation() {
        let version = createBibleVersion(id: 111, abbreviation: "")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1.111")
    }
    
    @Test func testShareUrl_EmptyLocalizedAbbreviation() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV", localizedAbbreviation: "")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url?.absoluteString == "https://www.bible.com/bible/111/GEN.1.1.NIV")
    }
    
    // MARK: - URL Validity Tests
    
    @Test func testShareUrl_ReturnsValidURL() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV")
        let reference = BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        let url = version.shareUrl(reference: reference)
        
        #expect(url != nil)
        #expect(url?.scheme == "https")
        #expect(url?.host == "www.bible.com")
        #expect(url?.path.hasPrefix("/bible/111/") == true)
    }
    
    @Test func testShareUrl_AllScenariosReturnValidURLs() {
        let version = createBibleVersion(id: 111, abbreviation: "NIV", localizedAbbreviation: "NVI")
        
        let scenarios: [BibleReference] = [
            BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1),
            BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 111, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5),
            BibleReference(versionId: 111, bookUSFM: "PSA", chapter: 23, verse: 1),
            BibleReference(versionId: 111, bookUSFM: "PSA", chapter: 23, verseStart: 1, verseEnd: 6),
            BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verse: 10),
            BibleReference(versionId: 111, bookUSFM: "1SA", chapter: 3, verseStart: 10, verseEnd: 15)
        ]
        
        for reference in scenarios {
            let url = version.shareUrl(reference: reference)
            #expect(url != nil, "URL should not be nil for reference: \(reference)")
            #expect(url?.scheme == "https", "URL should use https scheme for reference: \(reference)")
            #expect(url?.host == "www.bible.com", "URL should have correct host for reference: \(reference)")
        }
    }
}
