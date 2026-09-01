import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    func openSearch() {
        showingSearchSheet = true
    }

    func searchIfNeeded() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            completedSearchQuery = nil
            completedSearchVersionID = nil
            searchRequestID = nil
            searchResults = []
            searchResultTextByUSFM = [:]
            searchScrollPosition = nil
            isSearching = false
            hasCompletedSearch = false
            searchFailed = false
            return
        }
        let versionId = reference.versionId
        guard query != completedSearchQuery || versionId != completedSearchVersionID else {
            return
        }

        let requestID = UUID()
        searchRequestID = requestID
        isSearching = false
        searchFailed = false
        do {
            try await ContinuousClock().sleep(for: .milliseconds(300))
            try Task.checkCancellation()
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            isSearching = true
            let results = try await YouVersionAPI.Search.verses(query: query, bibleID: versionId)
            try Task.checkCancellation()
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            searchResultTextByUSFM = [:]
            searchResults = results.verses.filter { $0.bibleReference(versionID: versionId) != nil }
            searchResultSetID = UUID()
            searchScrollPosition = nil
            completedSearchQuery = query
            completedSearchVersionID = versionId
            isSearching = false
            hasCompletedSearch = true
            searchFailed = false
        } catch is CancellationError {
            if requestID == searchRequestID {
                isSearching = false
            }
        } catch {
            guard requestID == searchRequestID,
                  query == searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            searchResults = []
            searchResultTextByUSFM = [:]
            searchScrollPosition = nil
            completedSearchQuery = nil
            completedSearchVersionID = nil
            isSearching = false
            hasCompletedSearch = false
            searchFailed = true
            YouVersionPlatformLogger.error("Bible search failed: \(error)", category: "Reader")
        }
    }

    func loadVerseText(for result: YouVersionVerseSearchResult, resultSetID: UUID) async {
        guard resultSetID == searchResultSetID,
              searchResultTextByUSFM[result.reference] == nil,
              let reference = result.bibleReference(versionID: reference.versionId) else {
            return
        }
        guard let text = try? await BibleVersionRendering.plainTextOf(reference) else {
            return
        }
        guard resultSetID == searchResultSetID else {
            return
        }
        searchResultTextByUSFM[result.reference] = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectSearchResult(_ result: YouVersionVerseSearchResult) async {
        guard let reference = result.bibleReference(versionID: reference.versionId) else {
            return
        }
        showingSearchSheet = false
        await goToReference(reference, showsFullChapter: true, shouldFocus: true)
    }

}
