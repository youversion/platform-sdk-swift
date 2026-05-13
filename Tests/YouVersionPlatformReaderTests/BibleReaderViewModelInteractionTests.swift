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

        viewModel.handleScroll(offset: -5)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: -30)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -25)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -5)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: 0)
        #expect(viewModel.showChrome)
    }

    @Test
    func handleScrollFiresChapterCompleteWhenScrolledPastOneAndAHalfViewports() {
        var completedReference: BibleReference?
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)
        let viewModel = Support.makeViewModel(
            reference: reference,
            onChapterComplete: { completedReference = $0 }
        )
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        // Scrolling less than 1.5x viewport should not fire
        viewModel.handleScroll(offset: -1000)
        #expect(completedReference == nil)

        // Scrolling beyond 1.5x viewport (offset < -(800 * 1.5) = -1200) should fire
        viewModel.handleScroll(offset: -1300)
        #expect(completedReference == reference)
    }

    @Test
    func handleScrollFiresChapterCompleteAtMostOncePerChapter() {
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        viewModel.handleScroll(offset: -1300)
        viewModel.handleScroll(offset: -1500)
        viewModel.handleScroll(offset: -2000)

        #expect(callCount == 1)
    }

    @Test
    func handleScrollResetsChapterCompleteOnReferenceChange() {
        var callCount = 0
        let viewModel = Support.makeViewModel(onChapterComplete: { _ in callCount += 1 })
        viewModel.scrollViewHeight = 800
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        viewModel.handleScroll(offset: -1300)
        #expect(callCount == 1)

        viewModel.resetChapterCompleteTracking()
        viewModel.handleScroll(offset: -1300)
        #expect(callCount == 2)
    }

    @Test
    func handleScrollDoesNothingWhileChangingChapter() {
        let viewModel = Support.makeViewModel()
        viewModel.isChangingChapter = true
        viewModel.lastScrollOffset = -30
        viewModel.showChrome = true

        viewModel.handleScroll(offset: -100)

        #expect(viewModel.lastScrollOffset == -30)
        #expect(viewModel.showChrome)
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
