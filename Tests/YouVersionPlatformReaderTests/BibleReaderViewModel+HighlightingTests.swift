import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

@MainActor
@Suite(.serialized) struct BibleReaderViewModelHighlightingTests {
    private typealias Support = BibleReaderViewModelTestSupport
    private static let versionId = 3034

    @Test
    func highlightHexesOnSelectedVersesDedupesIgnoringCase() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let firstReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let secondReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 17)
        let unselectedReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 19)
        let duplicateReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 20)
        viewModel.selectedVerses = [firstReference, secondReference, duplicateReference]
        viewModel.highlightsViewModel.addHighlights(references: [firstReference], color: "FFFE00")
        viewModel.highlightsViewModel.addHighlights(references: [secondReference], color: "ffec5b")
        viewModel.highlightsViewModel.addHighlights(references: [duplicateReference], color: "fffe00")
        viewModel.highlightsViewModel.addHighlights(references: [unselectedReference], color: "00D6FF")

        #expect(viewModel.highlightHexesOnSelectedVerses == ["ffec5b", "fffe00"])
    }

    @Test
    func highlightHexesOnSelectedVersesKeepsSavedAlpha() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let reference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "#40000000")

        #expect(viewModel.highlightHexesOnSelectedVerses == ["#40000000"])
    }

    @Test
    func removeVerseColorHexRemovesMatchingRGBFromSelectedVersesOnly() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let legacyReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let paletteReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 17)
        let unselectedReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 18)
        viewModel.selectedVerses = [legacyReference, paletteReference]
        viewModel.highlightsViewModel.addHighlights(references: [legacyReference], color: "#80FFFE00")
        viewModel.highlightsViewModel.addHighlights(references: [paletteReference], color: "ffec5b")
        viewModel.highlightsViewModel.addHighlights(references: [unselectedReference], color: "fffe00")

        viewModel.removeVerseColor(hex: "#FFFE00")

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: legacyReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: paletteReference) == [
            BibleHighlight(paletteReference, color: "ffec5b"),
        ])
        #expect(viewModel.highlightsViewModel.highlights(for: unselectedReference) == [
            BibleHighlight(unselectedReference, color: "fffe00"),
        ])
    }

#if canImport(UIKit)
    @Test
    func removeVerseColorRemovesLegacyColorFromSelectedVersesOnly() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let legacyReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let paletteReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 17)
        let unselectedReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 18)
        viewModel.selectedVerses = [legacyReference, paletteReference]
        viewModel.highlightsViewModel.addHighlights(references: [legacyReference], color: "#FFFE00")
        viewModel.highlightsViewModel.addHighlights(references: [paletteReference], color: "ffec5b")
        viewModel.highlightsViewModel.addHighlights(references: [unselectedReference], color: "fffe00")

        viewModel.removeVerseColor(Color(hex: "fffe00"))

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: legacyReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: paletteReference) == [
            BibleHighlight(paletteReference, color: "ffec5b"),
        ])
        #expect(viewModel.highlightsViewModel.highlights(for: unselectedReference) == [
            BibleHighlight(unselectedReference, color: "fffe00"),
        ])
    }

    @Test
    func selectedVerseColorPresenceMatchesHexCaseInsensitivelyAndIgnoresHashPrefix() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let firstReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let secondReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 17)
        let unselectedReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 18)
        let selectedColor = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [firstReference, secondReference]
        viewModel.highlightsViewModel.addHighlights(references: [firstReference], color: "#ddaaff")
        viewModel.highlightsViewModel.addHighlights(references: [unselectedReference], color: "DDAAFF")

        #expect(viewModel.isColorPresentOnAllSelectedVerses(selectedColor) == false)

        viewModel.highlightsViewModel.addHighlights(references: [secondReference], color: "ddaaff")

        #expect(viewModel.isColorPresentOnAllSelectedVerses(selectedColor))
    }

    @Test
    func removeVerseColorRemovesMatchingHighlightsForSelectedVersesOnly() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: MockBibleHighlightsRepository()
        )
        let matchingReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let nonmatchingReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 17)
        let unselectedReference = BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3, verse: 18)
        let selectedColor = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [matchingReference, nonmatchingReference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.highlightsViewModel.addHighlights(references: [matchingReference], color: "#ddaaff")
        viewModel.highlightsViewModel.addHighlights(references: [nonmatchingReference], color: "00FF00")
        viewModel.highlightsViewModel.addHighlights(references: [unselectedReference], color: "DDAAFF")

        viewModel.removeVerseColor(selectedColor)

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.highlightsViewModel.highlights(for: matchingReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: nonmatchingReference) == [
            BibleHighlight(nonmatchingReference, color: "00FF00"),
        ])
        #expect(viewModel.highlightsViewModel.highlights(for: unselectedReference) == [
            BibleHighlight(unselectedReference, color: "DDAAFF"),
        ])
    }
#endif

    @Test
    func addAndRemoveVerseColorUpdateHighlightsForSelectedVerses() {
        Support.clearReaderDefaults()
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(
            highlightsRepository: highlightsRepository,
            isSignedIn: true,
            hasPermission: { $0 == "highlights" }
        )
        let firstReference = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let secondReference = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 17)
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

    @Test
    func isSameHexColorComparesColorsWithoutLeadingHashes() {
        let viewModel = Support.makeViewModel()

        #expect(viewModel.isSameHexColor("#DDAAFF", "DDAAFF"))
        #expect(viewModel.isSameHexColor("ddaaff", "#DDAAFF"))
        #expect(viewModel.isSameHexColor("#", "DDAAFF") == false)
        #expect(viewModel.isSameHexColor("#DDAAFF", "#AABBCC") == false)
        #expect(viewModel.isSameHexColor("nope", "nope") == false)
    }

    @Test
    func isSameHexColorMatchesShortAndArgbFormsOfTheSameColor() {
        let viewModel = Support.makeViewModel()

        #expect(viewModel.isSameHexColor("#FA3", "FFAA33"))
        #expect(viewModel.isSameHexColor("#80DDAAFF", "DDAAFF"))
    }

#if !canImport(UIKit)
    @Test
    func highlightColorActionsNoOpWhenColorCannotBeConverted() {
        Support.clearReaderDefaults()
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository)
        let reference = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16)
        let color = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [reference]
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        #expect(viewModel.isColorPresentOnAllSelectedVerses(color) == false)

        viewModel.addVerseColor(color)
        viewModel.removeVerseColor(color)

        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.highlightsViewModel.highlights(for: reference) == [BibleHighlight(reference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.count == 1)
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)
    }
#endif
}
