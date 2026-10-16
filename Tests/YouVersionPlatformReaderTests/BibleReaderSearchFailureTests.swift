import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
extension BibleReaderViewModelSearchTests {
    private typealias FailureSupport = BibleReaderViewModelTestSupport

    @Test(arguments: [403, 429, 500])
    func failedInitialRequestDoesNotBecomeAnEmptyResult(statusCode: Int) async {
        URLProtocol.registerClass(SearchFailureURLProtocol.self)
        defer { URLProtocol.unregisterClass(SearchFailureURLProtocol.self) }
        let viewModel = FailureSupport.makeViewModel()

        await viewModel.search(for: "YPE-6072-initial-\(statusCode)")

        #expect(viewModel.searchStatus == .failed)
        #expect(viewModel.searchResults.isEmpty)
        #expect(!viewModel.hasNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
    }

    @Test(arguments: [403, 429, 500])
    func failedNextPagePreservesResultsAndAllowsManualRetry(statusCode: Int) async {
        URLProtocol.registerClass(SearchFailureURLProtocol.self)
        defer { URLProtocol.unregisterClass(SearchFailureURLProtocol.self) }
        let viewModel = FailureSupport.makeViewModel()
        let query = "YPE-6072-pagination-\(UUID().uuidString)-\(statusCode)"
        await viewModel.search(for: query)
        let results = viewModel.searchResults
        #expect(results.map(\.passageId) == ["JHN.3.16"])

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchStatus == .completed)
        #expect(viewModel.searchResults == results)
        #expect(viewModel.hasNextSearchPageLoadError)
        #expect(viewModel.nextSearchPageToken == "failed-page")
        #expect(!viewModel.isLoadingNextSearchPage)

        await viewModel.loadNextSearchPageIfNeeded()

        #expect(viewModel.searchResults == results)
        #expect(viewModel.hasNextSearchPageLoadError)
        #expect(viewModel.nextSearchPageToken == "failed-page")
        #expect(!viewModel.isLoadingNextSearchPage)

        await viewModel.loadNextSearchPageIfNeeded()

        let pageTokens = await SearchFailureURLProtocol.pageTokens(for: query)
        #expect(pageTokens == [nil, "failed-page", "failed-page", "failed-page"])

        #expect(viewModel.searchResults.map(\.passageId) == ["JHN.3.16", "JHN.3.17"])
        #expect(!viewModel.hasNextSearchPageLoadError)
        #expect(!viewModel.hasNextSearchPage)
    }

    @Test
    func successfulEmptyResponseRetainsTheDistinctEmptyState() async {
        URLProtocol.registerClass(SearchFailureURLProtocol.self)
        defer { URLProtocol.unregisterClass(SearchFailureURLProtocol.self) }
        let viewModel = FailureSupport.makeViewModel()

        await viewModel.search(for: "YPE-6072-empty-200")

        #expect(viewModel.searchStatus == .completed)
        #expect(viewModel.searchResults.isEmpty)
        #expect(!viewModel.hasNextSearchPage)
        #expect(!viewModel.hasNextSearchPageLoadError)
    }
}

/// Intercepts only this suite's queries; status codes are synthetic request failures,
/// not a claim about the service's unconfirmed quota response contract.
/// Mutable fixture state is actor-isolated; protocol instances add no mutable state.
private final class SearchFailureURLProtocol: URLProtocol, @unchecked Sendable {
    private static let requests = SearchFailureRequests()

    /// Returns the continuation tokens actually requested for one test's query.
    static func pageTokens(for query: String) async -> [String?] {
        await requests.pageTokens(for: query)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url,
              url.path == "/v1/search-verses",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.queryItems?.contains {
            $0.name == "query" && ($0.value?.hasPrefix("YPE-6072-") ?? false)
        } == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = components.queryItems?.first(where: { $0.name == "query" })?.value,
              let statusCode = Int(query.split(separator: "-").last ?? "") else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let pageToken = components.queryItems?.first { $0.name == "page_token" }?.value
        Task {
            let attempt = await Self.requests.record(query: query, pageToken: pageToken)
            respond(url: url, query: query, pageToken: pageToken, statusCode: statusCode, attempt: attempt)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, query: String, pageToken: String?, statusCode: Int, attempt: Int) {
        let isFailure = query.contains("initial") || (pageToken == "failed-page" && attempt < 3)
        let responseCode = isFailure ? statusCode : 200
        let body: String
        if isFailure {
            body = "untrusted server error details"
        } else if query.contains("empty") {
            body = #"{"verses":[],"did_you_mean":[]}"#
        } else if pageToken == "failed-page" {
            body = #"{"verses":[{"reference":"JHN.3.17"}],"did_you_mean":[]}"#
        } else {
            body = #"{"verses":[{"reference":"JHN.3.16"}],"did_you_mean":[],"next_page_token":"failed-page"}"#
        }
        guard let response = HTTPURLResponse(url: url, statusCode: responseCode, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private actor SearchFailureRequests {
    private var pageTokensByQuery: [String: [String?]] = [:]

    /// Records a request and returns the number of continuation attempts for its query.
    func record(query: String, pageToken: String?) -> Int {
        pageTokensByQuery[query, default: []].append(pageToken)
        return pageTokensByQuery[query, default: []].compactMap { $0 }.count
    }

    /// Returns the recorded continuation tokens, including nil for the initial page.
    func pageTokens(for query: String) -> [String?] {
        pageTokensByQuery[query, default: []]
    }
}
