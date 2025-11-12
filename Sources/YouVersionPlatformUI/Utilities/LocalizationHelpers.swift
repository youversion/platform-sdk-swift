import Foundation

public extension String {
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: Bundle.YouVersionUIBundle, comment: "")
    }
}
