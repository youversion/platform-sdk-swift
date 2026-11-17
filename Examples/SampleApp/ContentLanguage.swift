import Foundation
import YouVersionPlatform

final class ContentLanguage: Sendable {
    let tag: String
    let videoSession: URLSession

    init(tag: String) {
        self.tag = tag
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Accept-Language": tag]
        videoSession = URLSession(configuration: configuration)
    }

    deinit {
        videoSession.invalidateAndCancel()
    }

    /// Returns an accessible Bible in this language for image search and scripture previews.
    func bibleID(for passageID: String? = nil) async throws -> Int {
        let languageTags: [String]
        switch tag {
        case "zh-CN": languageTags = [tag, "zh"]
        case "zh-TW", "zh-HK": languageTags = [tag, "zh-Hant", "zh"]
        default: languageTags = [tag]
        }
        for languageTag in languageTags {
            try Task.checkCancellation()
            let versions = try await YouVersionAPI.Bible.versions(forLanguageTag: languageTag)
            try Task.checkCancellation()
            let candidates = versions.filter { version in
                if let passageID {
                    guard let reference = BibleReference.unvalidatedReference(with: passageID, versionId: version.id) else {
                        return false
                    }
                    return version.bookIds.contains(reference.bookId)
                }
                return true
            }
            .sorted { $0.id < $1.id }
            if languageTag == "en" && candidates.contains(where: { $0.id == 3034 }) {
                return 3034
            }
            let version = candidates.first { $0.languageTag?.caseInsensitiveCompare(languageTag) == .orderedSame }
                ?? candidates.first
            if let version {
                return version.id
            }
        }
        throw passageID == nil ? ContentLanguageError.noBible : ContentLanguageError.passageUnavailable
    }
}

private enum ContentLanguageError: LocalizedError {
    case noBible
    case passageUnavailable

    var errorDescription: String? {
        switch self {
        case .noBible: String(localized: "No Bible is available for the selected language.")
        case .passageUnavailable: String(localized: "This passage is not available in the selected language.")
        }
    }
}
