import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct HTTPStatusErrorTests {
    enum Endpoint: CaseIterable, Sendable {
        case verseOfTheDay
        case chapter
        case versions
        case languages
    }

    private enum ExpectedError: Sendable {
        case missingAuthentication
        case notPermitted
        case cannotDownload
        case response(YouVersionAPIResponseError.Code)

        func matches(_ error: any Error) -> Bool {
            switch self {
            case .missingAuthentication:
                (error as? YouVersionAPIError) == .missingAuthentication
            case .notPermitted:
                (error as? YouVersionAPIError) == .notPermitted
            case .cannotDownload:
                (error as? YouVersionAPIError) == .cannotDownload
            case .response(let code):
                (error as? YouVersionAPIResponseError)?.code == code
            }
        }
    }

    private static let expectedErrors: [Int: ExpectedError] = [
        200: .cannotDownload,
        204: .cannotDownload,
        400: .response(.requestRejected),
        401: .missingAuthentication,
        403: .notPermitted,
        404: .response(.requestRejected),
        429: .response(.rateLimited),
        500: .response(.serverError),
        503: .response(.serverError),
    ]

    /// Returns whether `error` is the error an endpoint should throw for an HTTP `statusCode`.
    ///
    /// Returns `false` for status codes that have no expected error in this suite.
    static func isExpectedError(_ error: any Error, forStatusCode statusCode: Int) -> Bool {
        expectedErrors[statusCode]?.matches(error) ?? false
    }

    @Test(arguments: [400, 404, 409, 422])
    func clientErrorMapsToRequestRejected(statusCode: Int) {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: statusCode), data: Data())
        #expect((error as? YouVersionAPIResponseError)?.code == .requestRejected)
        #expect((error as? YouVersionAPIResponseError)?.statusCode == statusCode)
    }

    @Test func tooManyRequestsMapsToRateLimited() {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: 429), data: Data())
        #expect((error as? YouVersionAPIResponseError)?.code == .rateLimited)
    }

    @Test(arguments: [500, 502, 503, 504, 599])
    func serverStatusMapsToServerError(statusCode: Int) {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: statusCode), data: Data())
        #expect((error as? YouVersionAPIResponseError)?.code == .serverError)
        #expect((error as? YouVersionAPIResponseError)?.statusCode == statusCode)
    }

    @Test func unauthorizedStatusMapsToMissingAuthentication() {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: 401), data: Data())
        #expect((error as? YouVersionAPIError) == .missingAuthentication)
    }

    @Test func forbiddenStatusMapsToNotPermitted() {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: 403), data: Data())
        #expect((error as? YouVersionAPIError) == .notPermitted)
    }

    @Test(arguments: [100, 201, 204, 302, 304, 600])
    func unclassifiedStatusMapsToCannotDownload(statusCode: Int) {
        let error = YouVersionAPI.error(for: Self.httpResponse(statusCode: statusCode), data: Data())
        #expect((error as? YouVersionAPIError) == .cannotDownload)
    }

    @Test func rateLimitedErrorIncludesRetryAfterAndPlainTextMessage() throws {
        let response = Self.httpResponse(statusCode: 429, headers: ["Retry-After": "30", "Content-Type": "text/plain"])
        let error = try #require(YouVersionAPI.error(for: response, data: Data("Rate limit exceeded.\n".utf8)) as? YouVersionAPIResponseError)
        #expect(error.retryAfterSeconds == 30)
        #expect(error.message == "Rate limit exceeded.")
    }

    @Test func errorIncludesMessageFromBody() throws {
        let body = Data(#"{"message": "Bible version 99999999 not found"}"#.utf8)
        let error = try #require(YouVersionAPI.error(for: Self.httpResponse(statusCode: 404), data: body) as? YouVersionAPIResponseError)
        #expect(error.message == "Bible version 99999999 not found")
        #expect(error.retryAfterSeconds == nil)
        #expect(error.validationIssues.isEmpty)
    }

    @Test func errorIncludesFaultString() throws {
        let body = Data(#"{"fault": {"faultstring": "Quota violation", "detail": {"errorcode": "policies.ratelimit.QuotaViolation"}}}"#.utf8)
        let error = try #require(YouVersionAPI.error(for: Self.httpResponse(statusCode: 500), data: body) as? YouVersionAPIResponseError)
        #expect(error.message == "Quota violation")
    }

    @Test func errorIncludesDetailString() throws {
        let body = Data(#"{"detail": "Not Found"}"#.utf8)
        let error = try #require(YouVersionAPI.error(for: Self.httpResponse(statusCode: 404), data: body) as? YouVersionAPIResponseError)
        #expect(error.message == "Not Found")
        #expect(error.validationIssues.isEmpty)
    }

    @Test func errorIncludesValidationIssues() throws {
        let body = Data(#"""
        {"detail": [
            {"type": "missing", "loc": ["query", "language_ranges"], "msg": "Field required", "input": null},
            {"type": "too_long", "loc": ["query", "items", 3], "msg": "Too long", "input": "x"}
        ]}
        """#.utf8)
        let error = try #require(YouVersionAPI.error(for: Self.httpResponse(statusCode: 422), data: body) as? YouVersionAPIResponseError)
        #expect(error.validationIssues == [
            YouVersionAPIResponseError.ValidationIssue(location: ["query", "language_ranges"], message: "Field required"),
            YouVersionAPIResponseError.ValidationIssue(location: ["query", "items", "3"], message: "Too long"),
        ])
        #expect(error.message == "Field required")
    }

    @Test func unparseableBodyLeavesMessageEmpty() throws {
        let response = Self.httpResponse(statusCode: 502, headers: ["Content-Type": "text/html"])
        let error = try #require(YouVersionAPI.error(for: response, data: Data("<html>Bad Gateway</html>".utf8)) as? YouVersionAPIResponseError)
        #expect(error.message == nil)
    }

    @Test(arguments: [("120", 120.0), (" 5 ", 5.0), ("-3", 0.0)])
    func retryAfterSecondsParsesSeconds(value: String, expected: TimeInterval) {
        #expect(YouVersionAPI.retryAfterSeconds(from: value) == expected)
    }

    @Test func retryAfterSecondsParsesHTTPDate() {
        let now = Date(timeIntervalSince1970: 1_445_412_420)
        #expect(YouVersionAPI.retryAfterSeconds(from: "Wed, 21 Oct 2015 07:28:00 GMT", now: now) == 60)
        #expect(YouVersionAPI.retryAfterSeconds(from: "Wed, 21 Oct 2015 07:26:00 GMT", now: now) == 0)
    }

    @Test(arguments: [nil, "", "soon", "inf", "-infinity", "nan"])
    func retryAfterSecondsIgnoresMissingOrMalformedValues(value: String?) {
        #expect(YouVersionAPI.retryAfterSeconds(from: value) == nil)
    }

    @MainActor
    @Test(arguments: Endpoint.allCases, [401, 403, 404, 429, 500, 503])
    func endpointsThrowErrorForStatus(endpoint: Endpoint, statusCode: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
        }

        await #expect {
            try await response(from: endpoint, session: session)
        } throws: { error in
            Self.isExpectedError(error, forStatusCode: statusCode)
        }
    }

    private static func httpResponse(statusCode: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.youversion.com")!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
    }

    private func response(from endpoint: Endpoint, session: URLSession) async throws {
        switch endpoint {
        case .verseOfTheDay:
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        case .chapter:
            let reference = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
            _ = try await YouVersionAPI.Bible.chapter(reference: reference, accessToken: "swift-test-suite", session: session)
        case .versions:
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        case .languages:
            _ = try await YouVersionAPI.Languages.languages(accessToken: "swift-test-suite", session: session)
        }
    }
}
