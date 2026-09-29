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
        viewModel.trendingSearchQueries = [YouVersionSearchQuery(text: "love", source: nil)]
        viewModel.recentSearchQueries = ["peace"]

        viewModel.openSearch()

        #expect(viewModel.showingSearchSheet)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.nextSearchPageToken == nil)
        #expect(viewModel.nextSearchPageRequestID == nil)
        #expect(!viewModel.isLoadingNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
        #expect(viewModel.trendingSearchQueries.isEmpty)
        #expect(viewModel.recentSearchQueries.isEmpty)
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
            await viewModel.search(for: suggestion.text)
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

    @Test
    func nothingSavedMeansNoRecentSearches() {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test
    func unreadableSavedValueMeansNoRecentSearches() {
        Support.clearRecentSearches()
        UserDefaults.standard.set("not a list", forKey: Support.recentSearchesKey)
        let viewModel = Support.makeViewModel()

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test
    func newestRecentSearchComesFirst() {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()

        viewModel.recordRecentSearch("love")
        viewModel.recordRecentSearch("peace")

        #expect(viewModel.recentSearches == ["peace", "love"])
    }

    @Test
    func repeatedRecentSearchMovesToFrontRatherThanAppearingTwice() {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()

        viewModel.recordRecentSearch("love")
        viewModel.recordRecentSearch("peace")
        viewModel.recordRecentSearch("Love")

        #expect(viewModel.recentSearches == ["Love", "peace"])
    }

    @Test
    func onlyThreeNewestRecentSearchesAreKept() {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()

        viewModel.recordRecentSearch("love")
        viewModel.recordRecentSearch("peace")
        viewModel.recordRecentSearch("joy")
        viewModel.recordRecentSearch("hope")

        #expect(viewModel.recentSearches == ["hope", "joy", "peace"])
    }

    @Test
    func recentSearchIsSavedTrimmedAndBlankSearchIsNotSaved() {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()

        viewModel.recordRecentSearch("  love  ")
        viewModel.recordRecentSearch("   ")

        #expect(viewModel.recentSearches == ["love"])
    }

    @Test
    func recentSearchesAreRememberedAcrossViewModels() {
        Support.clearRecentSearches()
        Support.makeViewModel().recordRecentSearch("love")

        let reopenedViewModel = Support.makeViewModel()

        #expect(reopenedViewModel.recentSearches == ["love"])
    }

    @Test
    func emptySearchFieldOffersRecentSearchesWithoutWaiting() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        viewModel.recordRecentSearch("peace")
        viewModel.recordRecentSearch("love")

        let suggestionsTask = Task { await viewModel.updateSuggestedSearchQueries() }
        await Task.yield()

        #expect(viewModel.recentSearchQueries == ["love", "peace"])

        suggestionsTask.cancel()
        await suggestionsTask.value

        #expect(viewModel.recentSearchQueries == ["love", "peace"])
    }

    @Test
    func recentSearchesAreHiddenWhileTyping() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        viewModel.recordRecentSearch("love")
        viewModel.recentSearchQueries = ["love"]
        viewModel.searchQuery = "pea"

        let suggestionsTask = Task { await viewModel.updateSuggestedSearchQueries() }
        await Task.yield()

        #expect(viewModel.recentSearchQueries.isEmpty)

        suggestionsTask.cancel()
        await suggestionsTask.value
    }

    @Test
    func submittedSearchIsRememberedAsRecent() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        viewModel.searchQuery = " love "
        let searchTask = Task { await viewModel.search() }
        searchTask.cancel()

        await searchTask.value

        #expect(viewModel.recentSearches == ["love"])
    }

    @Test
    func tappedQueryIsRememberedAsRecent() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        let searchTask = Task {
            await viewModel.search(for: "peace")
        }
        searchTask.cancel()

        await searchTask.value

        #expect(viewModel.recentSearches == ["peace"])
    }

    @Test
    func blankSubmittedSearchIsNotRemembered() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        viewModel.searchQuery = "   "

        await viewModel.search()

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test
    func submittingSearchClearsTrendingAndRecentQueries() async {
        Support.clearRecentSearches()
        let viewModel = Support.makeViewModel()
        viewModel.searchQuery = "joy"
        viewModel.completedSearchQuery = "joy"
        viewModel.completedSearchVersionID = viewModel.reference.versionId
        viewModel.searchStatus = .completed
        viewModel.trendingSearchQueries = [YouVersionSearchQuery(text: "love", source: nil)]
        viewModel.recentSearchQueries = ["peace"]

        await viewModel.search()

        #expect(viewModel.trendingSearchQueries.isEmpty)
        #expect(viewModel.recentSearchQueries.isEmpty)
    }

    @Test
    func everySearchResultIsListedWhileFilterIsBoth() {
        let viewModel = Support.makeViewModel()
        viewModel.searchVersion = versionWithTestaments
        viewModel.searchResults = [john316, psalm231, tobit11]

        #expect(viewModel.searchCanonFilter == .both)
        #expect(viewModel.filteredSearchResults == [john316, psalm231, tobit11])
    }

    @Test
    func eachTestamentFilterListsOnlyResultsFromItsOwnBooks() {
        let viewModel = Support.makeViewModel()
        viewModel.searchVersion = versionWithTestaments
        viewModel.searchResults = [john316, psalm231, tobit11]

        viewModel.searchCanonFilter = .oldTestament
        #expect(viewModel.filteredSearchResults == [psalm231])

        viewModel.searchCanonFilter = .newTestament
        #expect(viewModel.filteredSearchResults == [john316])
    }

    @Test
    func longCanonNamesAreFilteredLikeShortOnes() {
        let viewModel = Support.makeViewModel()
        viewModel.searchVersion = makeVersion(books: [("JHN", "new_testament"), ("PSA", "old_testament")])
        viewModel.searchResults = [john316, psalm231]

        viewModel.searchCanonFilter = .oldTestament
        #expect(viewModel.filteredSearchResults == [psalm231])

        viewModel.searchCanonFilter = .newTestament
        #expect(viewModel.filteredSearchResults == [john316])
    }

    @Test
    func testamentFilterListsNothingWithoutSearchVersion() {
        let viewModel = Support.makeViewModel()
        viewModel.searchResults = [john316, psalm231]

        viewModel.searchCanonFilter = .newTestament

        #expect(viewModel.filteredSearchResults.isEmpty)
    }

    @Test
    func openingSearchPutsFilterBackToBoth() {
        let viewModel = Support.makeViewModel()
        viewModel.searchCanonFilter = .newTestament

        viewModel.openSearch()

        #expect(viewModel.searchCanonFilter == .both)
    }

    @Test
    func nextSearchPageIsOnlyReportedForNonEmptyToken() {
        let viewModel = Support.makeViewModel()

        viewModel.nextSearchPageToken = nil
        #expect(!viewModel.hasNextSearchPage)

        viewModel.nextSearchPageToken = ""
        #expect(!viewModel.hasNextSearchPage)

        viewModel.nextSearchPageToken = "next"
        #expect(viewModel.hasNextSearchPage)
    }

    private let john316 = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16)
    private let psalm231 = BibleReference(versionId: Support.versionId, bookId: "PSA", chapter: 23, verse: 1)
    private let tobit11 = BibleReference(versionId: Support.versionId, bookId: "TOB", chapter: 1, verse: 1)

    private var versionWithTestaments: BibleVersion {
        makeVersion(books: [("JHN", "nt"), ("PSA", "ot"), ("TOB", "deuterocanon")])
    }

    private func makeVersion(books: [(id: String, canon: String)]) -> BibleVersion {
        BibleVersion(
            id: Support.versionId,
            abbreviation: "TEST",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "TST",
            localizedTitle: "Test Version",
            readerFooter: nil,
            readerFooterUrl: nil,
            title: "Test Version",
            organizationId: nil,
            bookCodes: books.map(\.id),
            books: books.map { book in
                BibleBook(
                    id: book.id,
                    title: book.id,
                    fullTitle: book.id,
                    abbreviation: book.id,
                    canon: book.canon,
                    chapters: nil,
                    intro: nil
                )
            },
            textDirection: "ltr"
        )
    }
}
