import SwiftUI
import Testing
import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@MainActor
struct BibleVerseIndicatorTests {
    @Test
    func splitMarkerRunsShareOneBackgroundWithoutRepeatedAlphaFills() throws {
        let reference = BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: 3)
        let style = BibleVerseIndicatorStyle(backgroundColor: .gray.opacity(0.25), minimumHitTargetSize: CGSize(width: 30, height: 30))
        let indicator = BibleTextView.IndicatorAttribute(
            id: BibleTextView.IndicatorID(blockID: UUID(), runIndex: 0), reference: reference, style: style, isDimmed: false
        )
        let backgrounds = BibleTextView.mergedIndicatorBackgrounds([
            BibleTextView.IndicatorBackground(indicator: indicator, bounds: CGRect(x: 10, y: 5, width: 4, height: 12)),
            BibleTextView.IndicatorBackground(indicator: indicator, bounds: CGRect(x: 14, y: 5, width: 8, height: 12)),
            BibleTextView.IndicatorBackground(indicator: indicator, bounds: CGRect(x: 22, y: 5, width: 4, height: 12))
        ])
        #expect(backgrounds.count == 1)
        #expect(try #require(backgrounds.first).bounds == CGRect(x: 10, y: 5, width: 16, height: 12))
    }

    @Test
    func inlinePaddingUsesNonbreakingSpacesAndPreservesNumberAttributes() {
        var number = AttributedString("12")
        number.font = .caption
        number.baselineOffset = 4
        let style = BibleVerseIndicatorStyle(
            backgroundColor: .blue, minimumHitTargetSize: CGSize(width: 30, height: 30), hasInlinePadding: true
        )
        let padded = BibleTextView.paddedVerseIndicator(number, style: style)
        #expect(String(padded.characters) == "\u{00a0}12\u{00a0}")
        #expect(padded.runs.allSatisfy { $0.font == .caption && $0.baselineOffset == 4 })
        let plain = BibleVerseIndicatorStyle(backgroundColor: .blue, minimumHitTargetSize: CGSize(width: 30, height: 30))
        #expect(BibleTextView.paddedVerseIndicator(number, style: plain) == number)
    }

    @Test
    func allPublicInitializersRetainIndicatorCallbacksAndOldSignaturesRemainUsable() {
        let chapter = BibleReference(versionId: 3034, bookId: "GEN", chapter: 1)
        let reference = BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: 3)
        let style = BibleVerseIndicatorStyle(backgroundColor: .blue, minimumHitTargetSize: CGSize(width: 30, height: 30))
        var selected: [BibleReference] = []
        let provider: (BibleReference) -> BibleVerseIndicatorStyle? = { $0 == reference ? style : nil }
        let action: (BibleReference) -> Void = { selected.append($0) }
        let html = "<div class='yv-v' v='GEN.1.3'><span class='yv-vlbl'>3</span>Text.</div>"
        let views = [
            BibleTextView(chapter, verseIndicatorStyle: provider, onVerseIndicatorSelected: action),
            BibleTextView(chapter, selectedVerses: .constant([]), verseIndicatorStyle: provider, onVerseIndicatorSelected: action),
            BibleTextView(html: html, reference: chapter, verseIndicatorStyle: provider, onVerseIndicatorSelected: action)
        ]
        for view in views {
            #expect(view.verseIndicatorStyle?(reference) == style)
            #expect(view.verseIndicatorStyle?(BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: 2)) == nil)
            view.onVerseIndicatorSelected?(reference)
        }
        #expect(selected == [reference, reference, reference])
        #expect(BibleTextView(chapter).verseIndicatorStyle == nil)
        #expect(BibleTextView(chapter, selectedVerses: .constant([])).verseIndicatorStyle == nil)
        #expect(BibleTextView(html: html, reference: chapter).verseIndicatorStyle == nil)
    }
}
