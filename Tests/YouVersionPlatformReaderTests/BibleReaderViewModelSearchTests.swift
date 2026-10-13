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
            BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1),
            BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 2)
        ]
        viewModel.searchQuery = "the word"
        viewModel.searchResults = results
        viewModel.nextSearchPageToken = "next-page"
        viewModel.nextSearchPageRequestID = UUID()
        viewModel.hasNextSearchPageLoadError = true

        viewModel.openSearch()

        #expect(viewModel.showingSearchSheet)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
    }

    @Test
    func loadingNextPageWithoutContinuationTokenDoesNothing() async {
        let viewModel = Support.makeViewModel()
        let results = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
        viewModel.searchQuery = "word"
        viewModel.searchResults = results
        viewModel.completedSearchQuery = "word"
        viewModel.completedSearchVersionID = viewModel.reference.versionId

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults.map(\.passageId) == results.map(\.passageId))
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(viewModel.nextSearchPageRequestID == nil)
    }

    @Test
    func loadingNextPageRejectsStaleSearchState() async {
        let viewModel = Support.makeViewModel()
        let results = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
        viewModel.searchQuery = "joy"
        viewModel.searchResults = results
        viewModel.nextSearchPageToken = "next-page"
        viewModel.completedSearchQuery = "love"
        viewModel.completedSearchVersionID = viewModel.reference.versionId

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults.map(\.passageId) == results.map(\.passageId))
        #expect(viewModel.nextSearchPageToken == "next-page")
        #expect(viewModel.nextSearchPageRequestID == nil)

        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId + 1

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults.map(\.passageId) == results.map(\.passageId))
        #expect(viewModel.nextSearchPageToken == "next-page")
        #expect(viewModel.nextSearchPageRequestID == nil)
    }

    @Test
    func suggestionsDoNotShowProgressDuringDebounce() async {
        let viewModel = Support.makeViewModel()
        let existingResults = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
        viewModel.searchQuery = "peace"
        viewModel.searchResults = existingResults

        let searchTask = Task { await viewModel.updateSuggestedSearchQueries() }
        await Task.yield()

        #expect(viewModel.searchStatus == .idle)
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

        #expect(viewModel.suggestedSearchQueries.map(\.text) == suggestions.map(\.text))
        #expect(viewModel.searchQueryRequestID == nil)
    }

    @Test
    func searchingWhitespaceClearsPreviousResultsWithoutRequesting() async {
        let viewModel = Support.makeViewModel()
        let result = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)
        viewModel.searchQuery = "   "
        viewModel.searchResults = [result]
        viewModel.searchResultTextByPassageID[result.passageId] = "In the beginning"
        viewModel.completedSearchQuery = "beginning"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.nextSearchPageToken = "next-page"
        viewModel.searchStatus = .failed

        await viewModel.search()

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchResultTextByPassageID.isEmpty)
        #expect(viewModel.completedSearchQuery == nil)
        #expect(viewModel.completedSearchVersionID == nil)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(viewModel.searchStatus == .idle)
    }

    @Test
    func repeatedCompletedSearchPreservesResults() async {
        let viewModel = Support.makeViewModel()
        let results = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
        viewModel.searchQuery = "  joy  "
        viewModel.searchResults = results
        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.searchStatus = .completed
        viewModel.suggestedSearchQueries = [YouVersionSearchQuery(text: "joyful", source: nil)]

        await viewModel.search()

        #expect(viewModel.searchQuery == "joy")
        #expect(viewModel.submittedSearchQuery == "joy")
        #expect(viewModel.searchResults.map(\.passageId) == results.map(\.passageId))
        #expect(viewModel.suggestedSearchQueries.isEmpty)
        #expect(viewModel.searchStatus == .completed)
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
        #expect(viewModel.searchStatus == .idle)
    }

    @Test
    func cancellingNextPagePreservesResultsAndContinuationToken() async {
        let viewModel = Support.makeViewModel()
        let results = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
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

        #expect(viewModel.searchResults.map(\.passageId) == results.map(\.passageId))
        #expect(viewModel.nextSearchPageToken == "next-page")
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
    }

    @Test
    func loadingVerseTextUsesResultVersionAfterActiveVersionChanges() async throws {
        let versionID = 9_030_034
        let chapterReference = BibleReference(versionId: versionID, bookId: "JHN", chapter: 3)
        let result = BibleReference(versionId: versionID, bookId: "JHN", chapter: 3, verse: 16)
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
        let resultSetID = UUID()
        viewModel.searchRequestID = resultSetID
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        viewModel.reference = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3)

        await viewModel.loadVerseText(for: result, resultSetID: resultSetID)

        #expect(viewModel.reference.versionId != result.versionId)
        #expect(viewModel.searchResultTextByPassageID[result.passageId] == "For God so loved the world.")
        await BibleChapterRepository.shared.removeVersion(withId: versionID)
    }

    @Test
    func loadingVerseTextRejectsStaleAndPreviouslyLoadedResults() async {
        let viewModel = Support.makeViewModel()
        let result = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)
        let resultSetID = UUID()
        viewModel.searchRequestID = resultSetID
        viewModel.searchResultTextByPassageID[result.passageId] = "Existing text"

        await viewModel.loadVerseText(for: result, resultSetID: resultSetID)
        await viewModel.loadVerseText(for: result, resultSetID: UUID())

        #expect(viewModel.searchResultTextByPassageID == [result.passageId: "Existing text"])
    }

    @Test
    func openingSearchResetsStatus() {
        let viewModel = Support.makeViewModel()
        viewModel.searchQuery = "   "
        viewModel.searchResults = [BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1, verse: 1)]
        viewModel.searchStatus = .failed
        viewModel.searchVersion = Support.makeBibleVersion(id: Support.versionId)

        viewModel.openSearch()

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchStatus == .idle)
        #expect(viewModel.searchVersion == nil)
    }

    @Test
    func selectingResultRestoresSearchedVersionAndNavigatesToVerse() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        let activeVersionID = Support.versionId + 1
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: activeVersionID))
        viewModel.reference = BibleReference(versionId: activeVersionID, bookId: "JHN", chapter: 1)
        viewModel.showingSearchSheet = true

        await viewModel.selectSearchResult(BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16))

        #expect(!viewModel.showingSearchSheet)
        #expect(viewModel.reference == BibleReference(
            versionId: Support.versionId,
            bookId: "JHN",
            chapter: 3,
            verse: 16
        ))
        #expect(viewModel.version?.id == Support.versionId)
        #expect(viewModel.showsFullChapter)
        #expect(viewModel.scrollTarget?.reference.verseStart == 16)
    }

    @Test
    func resultTitlesUseSearchedVersionAfterActiveVersionChanges() {
        let viewModel = Support.makeViewModel()
        let searchedVersion = Support.makeBibleVersion(id: Support.versionId)
        let activeVersion = Support.makeBibleVersion(id: Support.versionId + 1, bookTitle: "Juan")
        let result = BibleReference(versionId: searchedVersion.id, bookId: "JHN", chapter: 3, verse: 16)
        viewModel.searchVersion = searchedVersion
        viewModel.versionsViewModel.switchToVersion(activeVersion)
        viewModel.reference = BibleReference(versionId: activeVersion.id, bookId: "JHN", chapter: 3)

        #expect(viewModel.searchResultTitle(for: result) == "John 3:16")
        #expect(viewModel.version?.bookName("JHN") == "Juan")
    }

    @Test
    func resultTitlesUsePassageIDWhenMatchingMetadataIsUnavailable() {
        let viewModel = Support.makeViewModel()
        let result = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16)
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        #expect(viewModel.searchResultTitle(for: result) == result.passageId)
        viewModel.searchVersion = Support.makeBibleVersion(id: Support.versionId + 1)
        #expect(viewModel.searchResultTitle(for: result) == result.passageId)
    }
}
