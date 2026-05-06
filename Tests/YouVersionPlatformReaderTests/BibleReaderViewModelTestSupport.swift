import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

actor MockBibleVersionRepository: BibleVersionRepositoryProtocol {
    private var requestedVersionIds: [Int] = []
    private var thrownError: Error?

    func requestedIds() -> [Int] {
        requestedVersionIds
    }

    func setThrownError(_ error: Error?) {
        thrownError = error
    }

    func versionIfCached(_ id: Int) async throws -> BibleVersion? {
        nil
    }

    func version(withId id: Int) async throws -> BibleVersion {
        requestedVersionIds.append(id)
        if let thrownError {
            throw thrownError
        }
        return BibleReaderViewModelTestSupport.makeBibleVersion(id: id)
    }

    func downloadVersion(withId id: Int) async throws {
    }

    nonisolated func downloadStatus(for id: Int) -> BibleVersionRepository.BibleVersionDownloadStatus {
        .notDownloadable
    }

    func removeVersion(withId id: Int) async {
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) async {
    }
}

@MainActor
final class MockBibleHighlightsRepository: BibleHighlightsRepositoryProtocol {
    private(set) var queuedOperations: [PendingHighlightOperation] = []

    func highlights(for references: [BibleReference]) async throws -> [String: [BibleHighlight]] {
        [:]
    }

    func queueOperation(_ operation: PendingHighlightOperation) {
        queuedOperations.append(operation)
    }
}

enum BibleReaderViewModelTestSupport {
    static let versionId = 3034
    static let referenceKey = "bible-reader-view--reference"
    static let displayIntroKey = "bible-reader-view--displayintro"
    static let readerSettingsKey = "bible-reader-view--readersettings"

    @MainActor
    static func makeViewModel(
        reference: BibleReference? = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1),
        highlightsRepository: MockBibleHighlightsRepository = MockBibleHighlightsRepository(),
        versionRepository: any BibleVersionRepositoryProtocol = MockBibleVersionRepository(),
        onVerseTap: ((BibleReference) -> Void)? = nil,
        isSignedIn: Bool = false,
        hasValidToken: Bool? = nil,
        signOut: @escaping @MainActor () -> Void = {}
    ) -> BibleReaderViewModel {
        let highlightsViewModel = BibleHighlightsViewModel(
            cache: BibleHighlightsCache(),
            repository: highlightsRepository
        )
        let versionsViewModel = BibleVersionsViewModel(versionRepository: versionRepository)
        let authentication = BibleReaderAuthentication(
            isSignedIn: { isSignedIn },
            hasValidToken: { hasValidToken ?? isSignedIn },
            signOut: signOut
        )
        return BibleReaderViewModel(
            reference: reference,
            highlightsViewModel: highlightsViewModel,
            versionsViewModel: versionsViewModel,
            onVerseTap: onVerseTap,
            authentication: authentication
        )
    }

    static func makeBibleVersion(id: Int) -> BibleVersion {
        BibleVersion(
            id: id,
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
            bookCodes: ["JHN"],
            books: [
                BibleBook(
                    id: "JHN",
                    title: "John",
                    fullTitle: "John",
                    abbreviation: "John",
                    canon: "nt",
                    chapters: (1...3).map { chapter in
                        BibleChapter(id: "JHN.\(chapter)", passageId: nil, title: "\(chapter)", verses: nil)
                    },
                    intro: nil
                ),
            ],
            textDirection: "ltr"
        )
    }

    static func clearReaderDefaults() {
        UserDefaults.standard.removeObject(forKey: referenceKey)
        UserDefaults.standard.removeObject(forKey: displayIntroKey)
        UserDefaults.standard.removeObject(forKey: readerSettingsKey)
    }

}

struct TestError: Error {}

struct StoredReaderSettings: Codable {
    let fontFamily: String?
    let fontSize: CGFloat?
    let lineSpacing: CGFloat?
    let colorTheme: Int?
}
