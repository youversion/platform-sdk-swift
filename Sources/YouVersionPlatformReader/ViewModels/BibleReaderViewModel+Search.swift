import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    var isLoadingNextSearchPage: Bool {
        nextSearchPageRequestID != nil
    }

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
            let queries = if query.isEmpty {
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
            suggestedSearchQueries = queries
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
        searchVersion = version
        searchStatus = .searching
        do {
            let results = try await YouVersionAPI.Search.verses(query: query, bibleID: versionID)
            try Task.checkCancellation()
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            searchResultTextByPassageID = [:]
            searchResults = results.references
            nextSearchPageToken = results.nextPageToken
            completedSearchQuery = query
            completedSearchVersionID = versionID
            searchStatus = .completed
        } catch {
            if isCancellation(error) {
                if requestID == searchRequestID {
                    searchRequestID = nil
                    searchStatus = .idle
                }
                return
            }
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            clearSearchResults()
            searchStatus = .failed
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
        hasNextSearchPageLoadError = false
        defer {
            if requestID == nextSearchPageRequestID {
                nextSearchPageRequestID = nil
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

            var existingReferences = Set(searchResults.map(\.passageId))
            let newResults = results.references.filter {
                existingReferences.insert($0.passageId).inserted
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

    func searchResultTitle(for result: BibleReference) -> String {
        guard let searchVersion, searchVersion.id == result.versionId else {
            return result.passageId
        }
        return searchVersion.displayTitle(for: result, includesVersionAbbreviation: false)
    }

    func loadVerseText(for result: BibleReference, resultSetID: UUID) async {
        guard resultSetID == searchRequestID && searchResultTextByPassageID[result.passageId] == nil else {
            return
        }
        guard let text = try? await BibleVersionRendering.plainTextOf(result) else {
            return
        }
        guard resultSetID == searchRequestID else {
            return
        }
        searchResultTextByPassageID[result.passageId] = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectSearchResult(_ result: BibleReference) async {
        showingSearchSheet = false
        await goToReference(result, showsFullChapter: true, shouldFocus: true)
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
        searchVersion = nil
        searchResultTextByPassageID = [:]
        searchStatus = .idle
        completedSearchQuery = nil
        completedSearchVersionID = nil
        searchRequestID = nil
        nextSearchPageToken = nil
        nextSearchPageRequestID = nil
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
