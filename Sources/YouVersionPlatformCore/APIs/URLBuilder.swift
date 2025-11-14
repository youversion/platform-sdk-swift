import Foundation

public enum URLBuilder {

    private static var baseURLComponents: URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = YouVersionPlatformConfiguration.apiHost
        return components
    }

    static func userURL(accessToken: String) -> URL? {
        var components = baseURLComponents
        components.path = "/auth/me"
        components.queryItems = [
            URLQueryItem(name: "lat", value: accessToken)
        ]
        return components.url
    }

    public static func authURL(
        appKey: String,
        requiredPermissions: Set<SignInWithYouVersionPermission> = [],
        optionalPermissions: Set<SignInWithYouVersionPermission> = []
    ) -> URL? {
        var components = baseURLComponents
        components.path = "/auth/login"
        // this data must be in query params since it's not a normal API call.
        components.queryItems = [
            URLQueryItem(name: "app_id", value: appKey),
            URLQueryItem(name: "language", value: "en"),  // TODO load from the system
            URLQueryItem(name: "required_perms", value: requiredPermissions.map { $0.rawValue }.joined(separator: ",")),
            URLQueryItem(name: "opt_perms", value: optionalPermissions.map { $0.rawValue }.joined(separator: ",")),
            URLQueryItem(name: "x-yvp-installation-id", value: YouVersionPlatformConfiguration.installId)
        ]
        return components.url
    }

    public static func votdURL(dayOfYear: Int) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/verse_of_the_days/\(dayOfYear)"
        return components.url
    }

    public static func versionURL(versionId: Int) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles/\(versionId)"
        return components.url
    }

    public static func versionIndexURL(versionId: Int) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles/\(versionId)/index"
        return components.url
    }

    public static func versionBooksURL(versionId: Int) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles/\(versionId)/books"
        return components.url
    }

    public static func versionBookChaptersURL(versionId: Int, book: String) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles/\(versionId)/books/\(book)/chapters"
        return components.url
    }

    /// URL to fetch text and metadata for a given BibleReference. "format" must be "text" or "html".
    public static func passageURL(reference: BibleReference, format: String = "text") -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles/\(reference.versionId)/passages/\(reference.asUSFM)"
        components.queryItems = [
            URLQueryItem(name: "format", value: format),
            URLQueryItem(name: "include_notes", value: "true"),
            URLQueryItem(name: "include_headings", value: "true")
        ]
        return components.url
    }

    public static func versionsURL(languageRanges: [String] = [], pageSize: Int = 25) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/bibles"

        let val = languageRanges.isEmpty ? "*" : languageRanges.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "language_ranges[]", value: val),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        return components.url
    }

    public static var highlightsURL: URL? {
        var components = baseURLComponents
        components.path = "/v1/highlights"
        return components.url
    }

    /// Returns a URL for getting highlights (GET) with query parameters, and create/update with POST
    public static func highlightsURL(bibleId: Int, passageId: String) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/highlights"
        components.queryItems = [
            URLQueryItem(name: "bible_id", value: String(bibleId)),
            URLQueryItem(name: "passage_id", value: passageId)
        ]
        return components.url
    }

    public static func highlightsDeleteURL(bibleId: Int, passageId: String) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/highlights/\(passageId)"
        components.queryItems = [
            URLQueryItem(name: "bible_id", value: String(bibleId))
        ]
        return components.url
    }

    public static func languagesURL(country: String?, pageSize: Int = 25) -> URL? {
        var components = baseURLComponents
        components.path = "/v1/languages"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if let country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }
        components.queryItems = queryItems
        return components.url
    }

}
