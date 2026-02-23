import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@MainActor
@Suite struct BibleVersionRenderingTests {
    private let fonts = BibleTextFonts(familyName: "Times New Roman", baseSize: 16)

    private func renderBlocks(
        html: String,
        reference: BibleReference,
        renderHeadlines: Bool = true
    ) async throws -> [BibleTextBlock] {
        let cache = ChapterDiskCache()
        let chapterReference = BibleReference(
            versionId: reference.versionId,
            bookUSFM: reference.bookUSFM,
            chapter: reference.chapter
        )
        await cache.removeVersion(versionId: reference.versionId)
        await cache.addChapterContent(html, reference: chapterReference)

        let blocks = try await BibleVersionRendering.textBlocks(
            reference,
            renderHeadlines: renderHeadlines,
            renderVerseNumbers: true,
            footnotesMode: .none,
            textColor: .black,
            wocColor: .red,
            fonts: fonts
        )

        let result = try #require(blocks)
        await cache.removeVersion(versionId: reference.versionId)
        return result
    }

    private func hasHeaderContaining(_ blocks: [BibleTextBlock], text: String) -> Bool {
        blocks.contains { block in
            let runs = block.text.asAttributedString.runs[\.bibleTextCategory]
            let hasHeader = runs.contains { $0.0 == .header }
            return hasHeader && block.text.characters.contains(text)
        }
    }

    private func hasScriptureContaining(_ blocks: [BibleTextBlock], text: String) -> Bool {
        blocks.contains { block in
            block.text.characters.contains(text)
        }
    }

    @Test func testHeaderBeforeFirstVerseInRangeIsRendered() async throws {
        let html = """
        <div>
            <div class="yv-h s1"><span>The List</span></div>
            <div class="p">
                <span class="yv-v" v="5"></span>
                <span class="yv-vlbl">5</span>
                Fifth verse text.
            </div>
            <div class="p">
                <span class="yv-v" v="6"></span>
                <span class="yv-vlbl">6</span>
                Sixth verse text.
            </div>
        </div>
        """

        let reference = BibleReference(
            versionId: 111,
            bookUSFM: "GEN",
            chapter: 1,
            verseStart: 5,
            verseEnd: 10
        )

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasHeaderContaining(blocks, text: "The List"))
        #expect(hasScriptureContaining(blocks, text: "Fifth verse text."))
    }

    @Test func testHeaderInMiddleOfLastVerseInRangeIsRendered() async throws {
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="5"></span>
                <span class="yv-vlbl">5</span>
                Part one of verse five.
            </div>
            <div class="yv-h s1"><span>Mid-Verse Header</span></div>
            <div class="p">
                Part two of verse five.
            </div>
        </div>
        """

        let reference = BibleReference(
            versionId: 112,
            bookUSFM: "GEN",
            chapter: 1,
            verseStart: 1,
            verseEnd: 5
        )

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasHeaderContaining(blocks, text: "Mid-Verse Header"))
        #expect(hasScriptureContaining(blocks, text: "Part one of verse five."))
        #expect(hasScriptureContaining(blocks, text: "Part two of verse five."))
    }

    @Test func testHeaderAfterLastVerseInRangeIsNotRendered() async throws {
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="5"></span>
                <span class="yv-vlbl">5</span>
                Fifth verse text.
            </div>
            <div class="yv-h s1"><span>Next Section</span></div>
            <div class="p">
                <span class="yv-v" v="6"></span>
                <span class="yv-vlbl">6</span>
                Sixth verse text.
            </div>
        </div>
        """

        let reference = BibleReference(
            versionId: 113,
            bookUSFM: "GEN",
            chapter: 1,
            verseStart: 1,
            verseEnd: 5
        )

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasScriptureContaining(blocks, text: "Fifth verse text."))
        #expect(!hasHeaderContaining(blocks, text: "Next Section"))
        #expect(!hasScriptureContaining(blocks, text: "Sixth verse text."))
    }

    @Test func testHeaderBeforeOutOfRangeVerseIsNotRendered() async throws {
        let html = """
        <div>
            <div class="yv-h s1"><span>Early Section</span></div>
            <div class="p">
                <span class="yv-v" v="3"></span>
                <span class="yv-vlbl">3</span>
                Third verse text.
            </div>
            <div class="p">
                <span class="yv-v" v="5"></span>
                <span class="yv-vlbl">5</span>
                Fifth verse text.
            </div>
        </div>
        """

        let reference = BibleReference(
            versionId: 114,
            bookUSFM: "GEN",
            chapter: 1,
            verseStart: 5,
            verseEnd: 10
        )

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(!hasHeaderContaining(blocks, text: "Early Section"))
        #expect(!hasScriptureContaining(blocks, text: "Third verse text."))
        #expect(hasScriptureContaining(blocks, text: "Fifth verse text."))
    }

    @Test func testHeaderIsNotRenderedWhenRenderHeadlinesIsFalse() async throws {
        let html = """
        <div>
            <div class="yv-h s1"><span>Visible Header</span></div>
            <div class="p">
                <span class="yv-v" v="1"></span>
                <span class="yv-vlbl">1</span>
                First verse text.
            </div>
        </div>
        """

        let reference = BibleReference(
            versionId: 115,
            bookUSFM: "GEN",
            chapter: 1,
            verseStart: 1,
            verseEnd: 5
        )

        let blocks = try await renderBlocks(html: html, reference: reference, renderHeadlines: false)
        #expect(!hasHeaderContaining(blocks, text: "Visible Header"))
        #expect(hasScriptureContaining(blocks, text: "First verse text."))
    }
}
