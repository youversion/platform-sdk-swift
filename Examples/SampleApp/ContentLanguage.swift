import Foundation
import YouVersionPlatform

struct ContentLanguage {
    let tag: String
    let videoSession: URLSession

    init(tag: String) {
        self.tag = tag
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Accept-Language": tag]
        videoSession = URLSession(configuration: configuration)
    }

    /// Returns an accessible Bible in this language for image search and scripture previews.
    func bibleID() async throws -> Int {
        let versions = try await YouVersionAPI.Bible.versions(forLanguageTag: tag)
        try Task.checkCancellation()
        if tag == "en" && versions.contains(where: { $0.id == 3034 }) {
            return 3034
        }
        if let id = versions.first?.id {
            return id
        }
        throw ContentLanguageError.noBible
    }
}

private enum ContentLanguageError: LocalizedError {
    case noBible

    var errorDescription: String? {
        String(localized: "No Bible is available for the selected language.")
    }
}
