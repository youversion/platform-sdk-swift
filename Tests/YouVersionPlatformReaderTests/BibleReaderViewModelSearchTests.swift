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
        viewModel.hasNextSearchPageLoadError = true

        viewModel.openSearch()

        #expect(viewModel.showingSearchSheet)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchScrollPosition == nil)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
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
    func loadingNextPageRejectsStaleSearchState() async {
        let viewModel = Support.makeViewModel()
        let results = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.searchQuery = "joy"
        viewModel.searchResults = results
        viewModel.nextSearchPageToken = "next-page"
        viewModel.completedSearchQuery = "love"
        viewModel.completedSearchVersionID = viewModel.reference.versionId

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults == results)
        #expect(viewModel.nextSearchPageToken == "next-page")
        #expect(viewModel.nextSearchPageRequestID == nil)

        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId + 1

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults == results)
        #expect(viewModel.nextSearchPageToken == "next-page")
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
    func unchangedSubmittedQueryPreservesSuggestions() async {
        let viewModel = Support.makeViewModel()
        let suggestions = [YouVersionSearchQuery(text: "joy", source: "community")]
        viewModel.searchQuery = "joy"
        viewModel.submittedSearchQuery = "joy"
        viewModel.suggestedSearchQueries = suggestions

        await viewModel.updateSuggestedSearchQueries()

        #expect(viewModel.suggestedSearchQueries == suggestions)
        #expect(viewModel.searchQueryRequestID == nil)
    }

    @Test
    func searchingWhitespaceClearsPreviousResultsWithoutRequesting() async {
        let viewModel = Support.makeViewModel()
        let result = YouVersionVerseSearchResult(reference: "JHN.1.1")
        viewModel.searchQuery = "   "
        viewModel.searchResults = [result]
        viewModel.searchResultTextByUSFM[result.reference] = "In the beginning"
        viewModel.searchScrollPosition = result.reference
        viewModel.completedSearchQuery = "beginning"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.nextSearchPageToken = "next-page"
        viewModel.isSearching = true
        viewModel.hasCompletedSearch = true
        viewModel.searchFailed = true

        await viewModel.search()

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchResultTextByUSFM.isEmpty)
        #expect(viewModel.searchScrollPosition == nil)
        #expect(viewModel.completedSearchQuery == nil)
        #expect(viewModel.completedSearchVersionID == nil)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(!viewModel.isSearching)
        #expect(!viewModel.hasCompletedSearch)
        #expect(!viewModel.searchFailed)
    }

    @Test
    func repeatedCompletedSearchPreservesResults() async {
        let viewModel = Support.makeViewModel()
        let results = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.searchQuery = "  joy  "
        viewModel.searchResults = results
        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.hasCompletedSearch = true
        viewModel.suggestedSearchQueries = [YouVersionSearchQuery(text: "joyful", source: nil)]

        await viewModel.search()

        #expect(viewModel.searchQuery == "joy")
        #expect(viewModel.submittedSearchQuery == "joy")
        #expect(viewModel.searchResults == results)
        #expect(viewModel.suggestedSearchQueries.isEmpty)
        #expect(viewModel.hasCompletedSearch)
    }

    @Test
    func selectingSuggestionSubmitsItsTextAndHandlesCancellation() async {
        let viewModel = Support.makeViewModel()
        let suggestion = YouVersionSearchQuery(text: "joy", source: "community")
        viewModel.suggestedSearchQueries = [suggestion]
        let searchTask = Task {
            await viewModel.search(for: suggestion)
        }
        searchTask.cancel()

        await searchTask.value

        #expect(viewModel.searchQuery == "joy")
        #expect(viewModel.submittedSearchQuery == "joy")
        #expect(viewModel.suggestedSearchQueries.isEmpty)
        #expect(!viewModel.isSearching)
        #expect(!viewModel.searchFailed)
    }

    @Test
    func cancellingNextPagePreservesResultsAndContinuationToken() async {
        let viewModel = Support.makeViewModel()
        let results = [YouVersionVerseSearchResult(reference: "JHN.1.1")]
        viewModel.searchQuery = "joy"
        viewModel.searchResults = results
        viewModel.nextSearchPageToken = "next-page"
        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.hasNextSearchPageLoadError = true
        let searchTask = Task {
            await viewModel.loadNextSearchPageIfNeeded()
        }
        searchTask.cancel()

        await searchTask.value

        #expect(viewModel.searchResults == results)
        #expect(viewModel.nextSearchPageToken == "next-page")
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
    }

    @Test
    func loadingVerseTextUsesCachedChapterAndTrimsWhitespace() async throws {
        let versionID = 9_030_034
        let chapterReference = BibleReference(versionId: versionID, bookId: "JHN", chapter: 3)
        let result = YouVersionVerseSearchResult(reference: "JHN.3.16")
        let html = """
        <div>
            <div class="p">
                <span class="yv-v" v="16"></span><span class="yv-vlbl">16</span>
                For God so loved the world.
            </div>
        </div>
        """
        let storage = BibleContentStorage(storageKind: .cache)
        let resource = BibleContentStorageResource.chapter(
            versionId: versionID,
            chapterPassageId: chapterReference.chapterPassageId
        )
        try storage.writeString(html, to: resource)
        try storage.writeExpirationDate(.distantFuture, for: resource)
        let viewModel = Support.makeViewModel(reference: chapterReference)
        let resultSetID = viewModel.searchResultSetID

        await viewModel.loadVerseText(for: result, resultSetID: resultSetID)

        #expect(viewModel.searchResultTextByUSFM[result.reference] == "For God so loved the world.")
        await BibleChapterRepository.shared.removeVersion(withId: versionID)
    }

    @Test
    func loadingVerseTextRejectsStaleMalformedAndPreviouslyLoadedResults() async {
        let viewModel = Support.makeViewModel()
        let result = YouVersionVerseSearchResult(reference: "JHN.1.1")
        viewModel.searchResultTextByUSFM[result.reference] = "Existing text"

        await viewModel.loadVerseText(for: result, resultSetID: viewModel.searchResultSetID)
        await viewModel.loadVerseText(
            for: YouVersionVerseSearchResult(reference: "malformed"),
            resultSetID: viewModel.searchResultSetID
        )
        await viewModel.loadVerseText(for: result, resultSetID: UUID())

        #expect(viewModel.searchResultTextByUSFM == [result.reference: "Existing text"])
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
