import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    func openSearch() {
        resetSearch()
        showingSearchSheet = true
    }

    func updateSuggestedSearchQueries() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != submittedSearchQuery else {
            return
        }

        let requestID = UUID()
        clearSearchResults()
        clearSuggestedSearchQueries()
        submittedSearchQuery = nil
        searchQueryRequestID = requestID

        do {
            if !query.isEmpty {
                try await ContinuousClock().sleep(for: .milliseconds(300))
            }
            try Task.checkCancellation()
            guard requestID == searchQueryRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            isLoadingSearchQueries = true
            let languageRange = if let languageTag = version?.languageTag, !languageTag.isEmpty {
                languageTag
            } else {
                "*"
            }
            let response = if query.isEmpty {
                try await YouVersionAPI.Search.trendingQueries(languageRanges: [languageRange])
            } else {
                try await YouVersionAPI.Search.suggestedQueries(
                    matching: query,
                    languageRanges: [languageRange]
                )
            }
            try Task.checkCancellation()
            guard requestID == searchQueryRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            suggestedSearchQueries = response.queries
            isLoadingSearchQueries = false
        } catch {
            if isCancellation(error) {
                if requestID == searchQueryRequestID {
                    isLoadingSearchQueries = false
                }
                return
            }
            guard requestID == searchQueryRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            clearSuggestedSearchQueries()
            YouVersionPlatformLogger.error("Search query suggestions failed: \(error)", category: "Reader")
        }
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearchResults()
            return
        }
        let versionID = reference.versionId
        submittedSearchQuery = query
        searchQuery = query
        clearSuggestedSearchQueries()
        guard query != completedSearchQuery || versionID != completedSearchVersionID else {
            return
        }

        clearSearchResults()
        let requestID = UUID()
        searchRequestID = requestID
        isSearching = true
        searchFailed = false
        do {
            let results = try await YouVersionAPI.Search.verses(query: query, bibleID: versionID)
            try Task.checkCancellation()
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            searchResultTextByUSFM = [:]
            searchResults = results.verses.filter { $0.bibleReference(versionID: versionID) != nil }
            nextSearchPageToken = results.nextPageToken
            searchResultSetID = UUID()
            searchScrollPosition = nil
            completedSearchQuery = query
            completedSearchVersionID = versionID
            isSearching = false
            hasCompletedSearch = true
            searchFailed = false
        } catch {
            if isCancellation(error) {
                if requestID == searchRequestID {
                    isSearching = false
                }
                return
            }
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            clearSearchResults()
            searchFailed = true
            YouVersionPlatformLogger.error("Bible search failed: \(error)", category: "Reader")
        }
    }

    func loadNextSearchPageIfNeeded() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionID = reference.versionId
        guard !isLoadingNextSearchPage,
              let pageToken = nextSearchPageToken,
              !pageToken.isEmpty,
              query == completedSearchQuery,
              versionID == completedSearchVersionID else {
            return
        }

        let requestID = UUID()
        nextSearchPageRequestID = requestID
        isLoadingNextSearchPage = true
        hasNextSearchPageLoadError = false
        defer {
            if requestID == nextSearchPageRequestID {
                nextSearchPageRequestID = nil
                isLoadingNextSearchPage = false
            }
        }
        do {
            let results = try await YouVersionAPI.Search.verses(
                query: query,
                bibleID: versionID,
                pageToken: pageToken
            )
            try Task.checkCancellation()
            guard requestID == nextSearchPageRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                  query == completedSearchQuery,
                  versionID == reference.versionId,
                  versionID == completedSearchVersionID else {
                return
            }

            var existingReferences = Set(searchResults.map(\.reference))
            let newResults = results.verses.filter {
                $0.bibleReference(versionID: versionID) != nil && existingReferences.insert($0.reference).inserted
            }
            searchResults.append(contentsOf: newResults)
            nextSearchPageToken = results.nextPageToken
        } catch {
            guard !isCancellation(error) else {
                return
            }
            guard requestID == nextSearchPageRequestID else {
                return
            }
            hasNextSearchPageLoadError = true
            YouVersionPlatformLogger.error(
                "Loading the next Bible search page failed: \(error)",
                category: "Reader"
            )
        }
    }

    func search(for suggestedQuery: YouVersionSearchQuery) async {
        searchQuery = suggestedQuery.text
        await search()
    }

    func loadVerseText(for result: YouVersionVerseSearchResult, resultSetID: UUID) async {
        guard resultSetID == searchResultSetID,
              searchResultTextByUSFM[result.reference] == nil,
              let verseReference = result.bibleReference(versionID: reference.versionId) else {
            return
        }
        guard let text = try? await BibleVersionRendering.plainTextOf(verseReference) else {
            return
        }
        guard resultSetID == searchResultSetID else {
            return
        }
        searchResultTextByUSFM[result.reference] = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectSearchResult(_ result: YouVersionVerseSearchResult) async {
        guard let verseReference = result.bibleReference(versionID: reference.versionId) else {
            return
        }
        showingSearchSheet = false
        await goToReference(verseReference, showsFullChapter: true, shouldFocus: true)
    }

    private func resetSearch() {
        searchQuery = ""
        submittedSearchQuery = nil
        clearSuggestedSearchQueries()
        clearSearchResults()
    }

    private func clearSuggestedSearchQueries() {
        suggestedSearchQueries = []
        isLoadingSearchQueries = false
        searchQueryRequestID = nil
    }

    private func clearSearchResults() {
        searchResults = []
        searchResultTextByUSFM = [:]
        searchScrollPosition = nil
        isSearching = false
        hasCompletedSearch = false
        searchFailed = false
        completedSearchQuery = nil
        completedSearchVersionID = nil
        searchRequestID = nil
        nextSearchPageToken = nil
        nextSearchPageRequestID = nil
        isLoadingNextSearchPage = false
        hasNextSearchPageLoadError = false
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let foundationError = error as NSError
        return foundationError.domain == NSURLErrorDomain && foundationError.code == NSURLErrorCancelled
    }

}
