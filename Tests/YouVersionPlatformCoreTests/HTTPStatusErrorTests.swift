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

    @Test(arguments: [400, 404, 409, 422])
    func clientErrorMapsToRequestRejected(statusCode: Int) {
        let error = YouVersionAPI.error(forStatusCode: statusCode)
        #expect((error as? YouVersionAPIResponseError)?.code == .requestRejected)
    }

    @Test func tooManyRequestsMapsToRateLimited() {
        let error = YouVersionAPI.error(forStatusCode: 429)
        #expect((error as? YouVersionAPIResponseError)?.code == .rateLimited)
    }

    @Test(arguments: [500, 502, 503, 504, 599])
    func serverStatusMapsToServerError(statusCode: Int) {
        let error = YouVersionAPI.error(forStatusCode: statusCode)
        #expect((error as? YouVersionAPIResponseError)?.code == .serverError)
    }

    @Test(arguments: [401, 403])
    func authorizationStatusMapsToNotPermitted(statusCode: Int) {
        let error = YouVersionAPI.error(forStatusCode: statusCode)
        #expect((error as? YouVersionAPIError) == .notPermitted)
    }

    @Test(arguments: [100, 201, 204, 302, 304, 600])
    func unclassifiedStatusMapsToCannotDownload(statusCode: Int) {
        let error = YouVersionAPI.error(forStatusCode: statusCode)
        #expect((error as? YouVersionAPIError) == .cannotDownload)
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
            Self.error(error, matchesStatusCode: statusCode)
        }
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

    enum ExpectedError: Sendable {
        case notPermitted
        case cannotDownload
        case response(YouVersionAPIResponseError.Code)

        func matches(_ error: any Error) -> Bool {
            switch self {
            case .notPermitted:
                (error as? YouVersionAPIError) == .notPermitted
            case .cannotDownload:
                (error as? YouVersionAPIError) == .cannotDownload
            case .response(let code):
                (error as? YouVersionAPIResponseError)?.code == code
            }
        }
    }

    static let expectedErrors: [Int: ExpectedError] = [
        200: .cannotDownload,
        204: .cannotDownload,
        400: .response(.requestRejected),
        401: .notPermitted,
        403: .notPermitted,
        404: .response(.requestRejected),
        429: .response(.rateLimited),
        500: .response(.serverError),
        503: .response(.serverError),
    ]

    static func error(_ error: any Error, matchesStatusCode statusCode: Int) -> Bool {
        expectedErrors[statusCode]?.matches(error) ?? false
    }
}
