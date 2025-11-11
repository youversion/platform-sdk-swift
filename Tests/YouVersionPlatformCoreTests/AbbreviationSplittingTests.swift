
import Foundation
import Testing
@testable import YouVersionPlatformCore

struct AbbreviationSplittingTests {

    // Test implementation that conforms to the protocol
    struct TestSplitter: AbbreviationSplitting {}

    let splitter = TestSplitter()

    @Test(arguments: [
        ("ESV", "ESV", ""),
        ("NIV1984", "NIV", "1984"),
        ("KJV21", "KJV", "21"),
        ("NKJV", "NKJV", ""),
        ("MSG", "MSG", ""),
        ("NLT", "NLT", ""),
        ("NASB1995", "NASB", "1995"),
        ("123", "", "123"),
        ("ABC123", "ABC", "123"),
        ("", "", ""),
        ("1", "", "1"),
        ("A1B2", "A1B", "2"),
        ("version2023", "version", "2023")
    ])
    func splitAbbreviation(input: String, expectedLetters: String, expectedNumbers: String) {
        let result = splitter.splitAbbreviation(input)
        #expect(result.letters == expectedLetters)
        #expect(result.numbers == expectedNumbers)
    }

    @Test
    func splitAbbreviationReturnsOriginalTextWhenNoNumbers() {
        let result = splitter.splitAbbreviation("NODIGITS")
        #expect(result.letters == "NODIGITS")
        #expect(result.numbers == "")
    }

    @Test
    func splitAbbreviationHandlesOnlyNumbers() {
        let result = splitter.splitAbbreviation("2023")
        #expect(result.letters == "")
        #expect(result.numbers == "2023")
    }

    @Test
    func splitAbbreviationHandlesEmptyString() {
        let result = splitter.splitAbbreviation("")
        #expect(result.letters == "")
        #expect(result.numbers == "")
    }

    @Test
    func splitAbbreviationHandlesNumbersInMiddle() {
        let result = splitter.splitAbbreviation("AB12CD34")
        #expect(result.letters == "AB12CD")
        #expect(result.numbers == "34")
    }
}
