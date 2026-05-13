import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

@MainActor
@Suite(.serialized) struct BibleReaderViewModelInteractionTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func handleScrollShowsAndHidesChromeAroundThreshold() {
        let viewModel = Support.makeViewModel()
        viewModel.showChrome = true

        viewModel.handleScroll(offset: -5, contentHeight: 4000)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: -30, contentHeight: 4000)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -25, contentHeight: 4000)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -5, contentHeight: 4000)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: 0, contentHeight: 4000)
        #expect(viewModel.showChrome)
    }

    @Test
    func handleScrollFiresChapterCompleteWhenBottomOfContentReached() {
        var completedReference: BibleReference?
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)
        let viewModel = Support.makeViewModel(
            reference: reference,
            onChapterComplete: { completedReference = $0 }
        )
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        // Content of height 2000 scrolled by -200 still has its bottom at 1800 — well below viewport bottom 800.
        viewModel.handleScroll(offset: -200, contentHeight: 2000)
        #expect(completedReference == nil)

        // Scrolled by -1200, the bottom of content is at 2000 - 1200 = 800 ≤ 800.
        // contentHeight has been stable at 2000 across two events → fires.
        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        #expect(completedReference == reference)
    }

    @Test
    func handleScrollFiresChapterCompleteForShortContentOnceHeightIsStable() {
        var completedReference: BibleReference?
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)
        let viewModel = Support.makeViewModel(
            reference: reference,
            onChapterComplete: { completedReference = $0 }
        )
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        // First geometry event for short content: height is not yet stable
        // (no prior observation), so the fire is suppressed.
        viewModel.handleScroll(offset: 0, contentHeight: 400)
        #expect(completedReference == nil)

        // Second event with the same height: layout has settled, fire allowed.
        viewModel.handleScroll(offset: 0, contentHeight: 400)
        #expect(completedReference == reference)
    }

    @Test
    func handleScrollSuppressesChapterCompleteDuringAsyncContentLoad() {
        // Reproduces the bug where onChapterComplete fired on initial open of
        // a long chapter: BibleTextView starts with empty blocks and lays out
        // tiny, then text loads and content grows past the viewport. We must
        // not fire during the tiny-initial-layout window.
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        // Initial layout: copyright block only, fits in viewport.
        viewModel.handleScroll(offset: 0, contentHeight: 120)
        #expect(callCount == 0)

        // Text loads — content height jumps to its real (long) value.
        viewModel.handleScroll(offset: 0, contentHeight: 3000)
        #expect(callCount == 0)

        // User has not scrolled yet; bottom is not reached.
        viewModel.handleScroll(offset: 0, contentHeight: 3000)
        #expect(callCount == 0)
    }

    @Test
    func handleScrollFiresChapterCompleteAtMostOncePerChapter() {
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        viewModel.handleScroll(offset: -1400, contentHeight: 2000)
        viewModel.handleScroll(offset: -1600, contentHeight: 2000)

        #expect(callCount == 1)
    }

    @Test
    func handleScrollResetsChapterCompleteOnReferenceChange() {
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        #expect(callCount == 1)

        viewModel.resetChapterCompleteTracking()
        // Sub-threshold scroll after reset must not fire.
        viewModel.handleScroll(offset: -100, contentHeight: 2000)
        viewModel.handleScroll(offset: -100, contentHeight: 2000)
        #expect(callCount == 1)

        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        viewModel.handleScroll(offset: -1200, contentHeight: 2000)
        #expect(callCount == 2)
    }

    @Test
    func handleScrollSkipsSideEffectsButRecordsGeometryWhileChangingChapter() {
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        viewModel.isChangingChapter = true
        viewModel.showChrome = true

        // Two consecutive stable-height events while the guard is active:
        // geometry is recorded but no side effects fire.
        viewModel.handleScroll(offset: 0, contentHeight: 400)
        viewModel.handleScroll(offset: 0, contentHeight: 400)

        #expect(viewModel.showChrome)
        #expect(callCount == 0)

        // The geometry was recorded, so the moment the guard clears, the
        // didSet on isChangingChapter re-evaluates and fires onChapterComplete.
        // This is what allows short chapters reached via prev/next to fire
        // without requiring any user scroll.
        viewModel.isChangingChapter = false
        #expect(callCount == 1)
    }

    @Test
    func handleVerseTapWithFootnoteActionShowsFootnotes() {
        let viewModel = Support.makeViewModel()
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        let footnote = BibleFootnote(text: BibleAttributedString("Footnote"), reference: reference, id: "one")

        viewModel.handleVerseTap(
            reference: reference,
            actionType: BibleVersionRendering.LinkSchemes.footnote.rawValue,
            footnotes: [footnote]
        )

        #expect(viewModel.showingFootnotes)
        #expect(viewModel.footnotesToDisplay == [footnote])
    }

    @Test
    func handleVerseTapUsesCustomVerseTapHandlerBeforeSelection() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        var tappedReference: BibleReference?
        let viewModel = Support.makeViewModel(onVerseTap: { tappedReference = $0; return .handled })

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(tappedReference == reference)
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
    }

    @Test
    func handleVerseTapTogglesSelectionWhenSignedIn() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.showingVerseActionsDrawer)

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
    }

    @Test
    func removeVerseSelectionClearsSelectionAndHidesDrawer() {
        let viewModel = Support.makeViewModel()
        viewModel.selectedVerses = [
            BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
        ]
        viewModel.showingVerseActionsDrawer = true

        viewModel.removeVerseSelection()

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
    }

    @Test
    func addAndRemoveVerseColorUpdateHighlightsForSelectedVerses() {
        Support.clearReaderDefaults()
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository)
        let firstReference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        let secondReference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 17)
        let color = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [firstReference, secondReference]

#if canImport(UIKit)
        viewModel.addVerseColor(color)

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.highlightsViewModel.highlights(for: firstReference) == [BibleHighlight(firstReference, color: "DDAAFF")])
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference) == [BibleHighlight(secondReference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)

        viewModel.selectedVerses = [firstReference, secondReference]
        #expect(viewModel.isColorPresentOnAnySelectedVerses(color))
        #expect(viewModel.isColorPresentOnAllSelectedVerses(color))

        viewModel.removeVerseColor(color)

        #expect(viewModel.highlightsViewModel.highlights(for: firstReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference).isEmpty)
        #expect(highlightsRepository.queuedOperations.last?.operationType == .remove)
#else
        viewModel.addVerseColor(color)

        #expect(viewModel.selectedVerses == [firstReference, secondReference])
        #expect(viewModel.highlightsViewModel.highlights(for: firstReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
#endif
    }

#if !canImport(UIKit)
    @Test
    func highlightColorActionsNoOpWhenColorCannotBeConverted() {
        Support.clearReaderDefaults()
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        let color = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [reference]
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        #expect(viewModel.isColorPresentOnAnySelectedVerses(color) == false)
        #expect(viewModel.isColorPresentOnAllSelectedVerses(color) == false)

        viewModel.addVerseColor(color)
        viewModel.removeVerseColor(color)

        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.highlightsViewModel.highlights(for: reference) == [BibleHighlight(reference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.count == 1)
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)
    }
#endif

    @Test
    func shareableURLAndTitleUsesMergedSelectionAndCurrentVersion() throws {
        let viewModel = Support.makeViewModel()
        let version = Support.makeBibleVersion(id: Support.versionId)
        viewModel.versionsViewModel.switchToVersion(version)
        viewModel.selectedVerses = [
            BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 17),
            BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
        ]

        let result = try #require(viewModel.shareableURLAndTitleForSelection)

        #expect(result.0.absoluteString == "https://www.bible.com/bible/3034/JHN.3.16-17.TST")
        #expect(result.1 == "John 3:16-17 TST")
    }

    @Test
    func shareableURLAndTitleReturnsNilWithoutVersionOrReferences() {
        let viewModel = Support.makeViewModel()

        #expect(viewModel.shareableURLAndTitleForSelection == nil)

        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        #expect(viewModel.shareableURLAndTitleFor(references: []) == nil)
    }

    @Test
    func shareableVerseTextReturnsEmptyStringForEmptySelection() async {
        let viewModel = Support.makeViewModel()

        let text = await viewModel.shareableVerseText(references: [])

        #expect(text == "")
    }

    @Test
    func handleVerseActionCopyWithEmptySelectionDoesNothing() {
        let viewModel = Support.makeViewModel()
        viewModel.showingVerseActionsDrawer = true

        viewModel.handleVerseActionCopy()

        #expect(viewModel.showingVerseActionsDrawer)
        #expect(viewModel.selectedVerses.isEmpty)
    }
}
