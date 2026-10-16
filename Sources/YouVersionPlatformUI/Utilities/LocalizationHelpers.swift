import Foundation

public extension String {
    static func localized(_ key: String) -> String {
        let value = NSLocalizedString(key, tableName: "Localizable", bundle: Bundle.YouVersionUIBundle, comment: "")
        guard value.isEmpty, let englishBundle = Bundle.YouVersionUIEnglishBundle else {
            return value
        }
        return NSLocalizedString(key, tableName: "Localizable", bundle: englishBundle, comment: "")
    }
}

private extension Bundle {
    static let YouVersionUIEnglishBundle: Bundle? = Bundle.YouVersionUIBundle
        .path(forResource: "en", ofType: "lproj")
        .flatMap { Bundle(path: $0) }
}
