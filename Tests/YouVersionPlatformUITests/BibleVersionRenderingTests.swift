import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@MainActor
@Suite struct BibleVersionRenderingTests {
    private let defaultVersionId = 1
    private let fonts = BibleTextFonts(familyName: "Times New Roman", baseSize: 16)

    private func renderBlocks(
        html: String,
        reference: BibleReference,
        renderHeadlines: Bool = true
    ) async throws -> [BibleTextBlock] {
        let node = try BibleTextNode(html: html)

        let blocks = try await BibleVersionRendering.textBlocks(
            from: node,
            reference: reference,
            renderHeadlines: renderHeadlines,
            renderVerseNumbers: true,
            footnotesMode: .none,
            textColor: .black,
            wocColor: .red,
            fonts: fonts
        )

        return try #require(blocks)
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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10)

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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasHeaderContaining(blocks, text: "Mid-Verse Header"))
        #expect(hasScriptureContaining(blocks, text: "Part one of verse five."))
        #expect(hasScriptureContaining(blocks, text: "Part two of verse five."))
    }

    @Test func testHeaderEmbeddedWithinVerseAfterInlineTextIsRendered() async throws {
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="2"></span>
                <span class="yv-vlbl">2</span>
                He said
                <div class="yv-h s1"><span>The Beatitudes</span></div>
                blessed are the poor in spirit.
            </div>
        </div>
        """

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "MAT", chapter: 5, verseStart: 2, verseEnd: 2)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasHeaderContaining(blocks, text: "The Beatitudes"))
    }

    @Test func testHeaderFollowingVerseTwoIsRenderedForRangeOneToTwo() async throws {
        let html = """
        <div>
            <div class="s1 yv-h">Introduction to the Sermon on the Mount</div>
            <div class="p">
                <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>
                When Jesus saw the crowds, He went up on the mountain and sat down.
                <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>
                and he began to teach them.
            </div>
            <div class="s1 yv-h">The Beatitudes</div>
            <div class="m">He said:</div>
            <div class="q1">
                <span class="yv-v" v="3"></span><span class="yv-vlbl">3</span>
                Blessed are the poor in spirit.
            </div>
        </div>
        """

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "MAT", chapter: 5, verseStart: 1, verseEnd: 2)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasHeaderContaining(blocks, text: "Introduction to the Sermon on the Mount"))
        #expect(hasHeaderContaining(blocks, text: "The Beatitudes"))
        #expect(hasScriptureContaining(blocks, text: "He said:"))
        #expect(!hasScriptureContaining(blocks, text: "Blessed are the poor in spirit."))
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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasScriptureContaining(blocks, text: "Fifth verse text."))
        #expect(!hasHeaderContaining(blocks, text: "Next Section"))
        #expect(!hasScriptureContaining(blocks, text: "Sixth verse text."))
    }

    @Test func testGenesisTwoOneToThreeDoesNotIncludeEndHeader() async throws {
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>
                Thus the heavens and the earth were completed in all their vast array.
                <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>
                By the seventh day God had finished the work He had been doing.
                <span class="yv-v" v="3"></span><span class="yv-vlbl">3</span>
                Then God blessed the seventh day and sanctified it.
            </div>
            <div class="s1 yv-h">Man and Woman in the Garden</div>
            <div class="p">
                <span class="yv-v" v="4"></span><span class="yv-vlbl">4</span>
                This is the account of the heavens and the earth when they were created.
            </div>
        </div>
        """

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 2, verseStart: 1, verseEnd: 3)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(hasScriptureContaining(blocks, text: "Thus the heavens and the earth were completed"))
        #expect(!hasHeaderContaining(blocks, text: "Man and Woman in the Garden"))
        #expect(!hasScriptureContaining(blocks, text: "This is the account of the heavens and the earth"))
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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(!hasHeaderContaining(blocks, text: "Early Section"))
        #expect(!hasScriptureContaining(blocks, text: "Third verse text."))
        #expect(hasScriptureContaining(blocks, text: "Fifth verse text."))
    }

    @Test func testYvVLblWithoutFollowingYvVUpdatesVerseForScripture() async throws {
        // Real chapter HTML can repeat only yv-vlbl for verses 2+ in a paragraph; if stateUp.verse
        // is not updated from the label, all text after verse 1 stays tagged as verse 1.
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="1"></span>
                <span class="yv-vlbl">1</span>
                First.
                <span class="yv-vlbl">2</span>
                Second.
                <span class="yv-v" v="3"></span>
                <span class="yv-vlbl">3</span>
                Third.
            </div>
        </div>
        """
        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "JHN", chapter: 1, verseStart: 1, verseEnd: 10)
        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(blocks.count == 1)
        let s = blocks[0].text.asAttributedString
        var verseBySnippet: [String: Int?] = [:]
        for run in s.runs[\.bibleTextCategory, \.bibleReference] {
            guard run.0 == .scripture, let ref = run.1 else { continue }
            let text = String(s[run.2].characters)
            for key in ["First", "Second", "Third"] where text.contains(key) {
                verseBySnippet[key] = ref.verseStart
            }
        }
        #expect(verseBySnippet["First"] == 1)
        #expect(verseBySnippet["Second"] == 2)
        #expect(verseBySnippet["Third"] == 3)
    }

    @Test func testYvVLblWithNestedSpanStillUpdatesVerseForScripture() async throws {
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="1"></span>
                <span class="yv-vlbl">1</span>
                First.
                <span class="yv-vlbl"><span class="inner">2</span></span>
                Second.
            </div>
        </div>
        """
        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "JHN", chapter: 1, verseStart: 1, verseEnd: 10)
        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(blocks.count == 1)
        let s = blocks[0].text.asAttributedString
        var verseBySnippet: [String: Int?] = [:]
        for run in s.runs[\.bibleTextCategory, \.bibleReference] {
            guard run.0 == .scripture, let ref = run.1 else { continue }
            let text = String(s[run.2].characters)
            for key in ["First", "Second"] where text.contains(key) {
                verseBySnippet[key] = ref.verseStart
            }
        }
        #expect(verseBySnippet["First"] == 1)
        #expect(verseBySnippet["Second"] == 2)
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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)

        let blocks = try await renderBlocks(html: html, reference: reference, renderHeadlines: false)
        #expect(!hasHeaderContaining(blocks, text: "Visible Header"))
        #expect(hasScriptureContaining(blocks, text: "First verse text."))
    }

    // MARK: - firstVerse (scroll-to-verse support)

    private func block(_ blocks: [BibleTextBlock], containingText text: String) throws -> BibleTextBlock {
        try #require(blocks.first { $0.text.characters.contains(text) })
    }

    @Test func testFirstVerseReflectsBlockVerses() async throws {
        let html = """
        <div>
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

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 5, verseEnd: 10)

        let blocks = try await renderBlocks(html: html, reference: reference)
        #expect(try block(blocks, containingText: "Fifth verse text.").firstVerse == 5)
        #expect(try block(blocks, containingText: "Sixth verse text.").firstVerse == 6)
    }

    @Test func testFirstVerseIsNilForHeaderOnlyBlock() async throws {
        let html = """
        <div>
            <div class="yv-h s1"><span>The List</span></div>
            <div class="p">
                <span class="yv-v" v="1"></span>
                <span class="yv-vlbl">1</span>
                First verse text.
            </div>
        </div>
        """

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)

        let blocks = try await renderBlocks(html: html, reference: reference)
        let headerBlock = try #require(blocks.first { block in
            block.text.asAttributedString.runs[\.bibleTextCategory].contains { $0.0 == .header }
                && block.text.characters.contains("The List")
        })
        #expect(headerBlock.firstVerse == nil)
    }

    @Test func testFirstVerseOfBlockSpanningMultipleVerses() async throws {
        // A single paragraph carrying two verses reports the first, so a scroll
        // request for either verse resolves to this block's start.
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="1"></span>
                <span class="yv-vlbl">1</span>
                First verse text.
                <span class="yv-v" v="2"></span>
                <span class="yv-vlbl">2</span>
                Second verse text.
            </div>
        </div>
        """

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 5)

        let blocks = try await renderBlocks(html: html, reference: reference)
        let combined = try block(blocks, containingText: "Second verse text.")
        #expect(combined.firstVerse == 1)

        let firstVerses = blocks.compactMap { $0.firstVerse }
        let layout = ChapterScrollAnchors(chapter: 1, blockFirstVerses: firstVerses)
        #expect(layout.blockFirstVerse(forTargetVerse: 1) == 1)
        #expect(layout.blockFirstVerse(forTargetVerse: 2) == 1)
    }

    @Test func testAcrosticChapterResolvesTargetVerseToOwningBlock() async throws {
        // Mirrors Psalm 119's shape: stanzas of verses separated by letter
        // headings, rendered as a full chapter. Verse 105 must resolve to its own
        // block, not an earlier one — a regression where headings desynced the
        // recorded verses from block identity landed scrolls on the wrong verse.
        var html = "<div>"
        let stanzas = [(letter: "MEM", start: 97), (letter: "NUN", start: 105), (letter: "SAMEKH", start: 113)]
        for stanza in stanzas {
            html += #"<div class="yv-h s1"><span>\#(stanza.letter)</span></div>"#
            for verse in stanza.start..<(stanza.start + 8) {
                html += #"""
                <div class="p">
                    <span class="yv-v" v="\#(verse)"></span>
                    <span class="yv-vlbl">\#(verse)</span>
                    Verse \#(verse) text.
                </div>
                """#
            }
        }
        html += "</div>"

        let reference = BibleReference(versionId: defaultVersionId, bookUSFM: "PSA", chapter: 119)
        let blocks = try await renderBlocks(html: html, reference: reference)

        let block105 = try block(blocks, containingText: "Verse 105 text.")
        #expect(block105.firstVerse == 105)

        let firstVerses = blocks.compactMap { $0.firstVerse }
        let layout = ChapterScrollAnchors(chapter: 119, blockFirstVerses: firstVerses)
        #expect(layout.blockFirstVerse(forTargetVerse: 105) == 105)
        #expect(layout.blockFirstVerse(forTargetVerse: 100) == 100)
        #expect(layout.blockFirstVerse(forTargetVerse: 113) == 113)
    }
}
