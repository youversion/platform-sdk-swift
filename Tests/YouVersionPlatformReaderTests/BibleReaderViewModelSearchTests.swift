import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelSearchTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func openingSearchResetsPreviousSearchForTrendingQueries() {
        let viewModel = Support.makeViewModel()
        let results = [
            YouVersionVerseSearchResult(reference: "JHN.1.1"),
            YouVersionVerseSearchResult(reference: "JHN.1.2")
        ]
        viewModel.searchQuery = "the word"
        viewModel.searchResults = results
        viewModel.searchScrollPosition = results[1].reference
        viewModel.nextSearchPageToken = "next-page"
        viewModel.nextSearchPageRequestID = UUID()
        viewModel.isLoadingNextSearchPage = true

        viewModel.openSearch()

        #expect(viewModel.showingSearchSheet)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchScrollPosition == nil)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
    }

    @Test
    func loadingNextPageWithoutContinuationTokenDoesNothing() async {
        let viewModel = Support.makeViewModel()
        let results = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.searchQuery = "word"
        viewModel.searchResults = results
        viewModel.completedSearchQuery = "word"
        viewModel.completedSearchVersionID = viewModel.reference.versionId

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults == results)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(viewModel.nextSearchPageRequestID == nil)
    }

    @Test
    func suggestionsDoNotShowProgressDuringDebounce() async {
        let viewModel = Support.makeViewModel()
        let existingResults = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.searchQuery = "peace"
        viewModel.searchResults = existingResults

        let searchTask = Task { await viewModel.updateSuggestedSearchQueries() }
        await Task.yield()

        #expect(!viewModel.isSearching)
        #expect(viewModel.searchResults.isEmpty)

        searchTask.cancel()
        await searchTask.value
    }

    @Test
    func openingSearchResetsStatus() {
        let viewModel = Support.makeViewModel()
        viewModel.searchQuery = "   "
        viewModel.searchResults = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.isSearching = true
        viewModel.hasCompletedSearch = true
        viewModel.searchFailed = true

        viewModel.openSearch()

        #expect(viewModel.searchResults.isEmpty)
        #expect(!viewModel.isSearching)
        #expect(!viewModel.hasCompletedSearch)
        #expect(!viewModel.searchFailed)
    }

    @Test
    func selectingResultDismissesSearchAndNavigatesToVerse() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        viewModel.showingSearchSheet = true

        await viewModel.selectSearchResult(YouVersionVerseSearchResult(reference: "JHN.3.16"))

        #expect(!viewModel.showingSearchSheet)
        #expect(viewModel.reference == BibleReference(
            versionId: Support.versionId,
            bookId: "JHN",
            chapter: 3,
            verse: 16
        ))
        #expect(viewModel.showsFullChapter)
        #expect(viewModel.scrollTarget?.reference.verseStart == 16)
    }

    @Test
    func selectingMalformedResultDoesNothing() async {
        let viewModel = Support.makeViewModel()
        let originalReference = viewModel.reference
        viewModel.showingSearchSheet = true

        await viewModel.selectSearchResult(YouVersionVerseSearchResult(reference: "not-a-reference"))

        #expect(viewModel.showingSearchSheet)
        #expect(viewModel.reference == originalReference)
    }
}
