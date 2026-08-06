import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CachedBibleContent<Value: Sendable>: Sendable {
    let value: Value
    let expirationDate: Date?
}

extension HTTPURLResponse {
    func cacheExpirationDate(currentDate: Date = Date()) -> Date? {
        guard let cacheControl = value(forHTTPHeaderField: "Cache-Control") else {
            return nil
        }

        let maxAge = cacheControl
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.lowercased().hasPrefix("max-age=") }?
            .split(separator: "=", maxSplits: 1)
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard let maxAge, let seconds = TimeInterval(maxAge), seconds >= 0 else {
            return nil
        }
        return currentDate.addingTimeInterval(seconds)
    }
}
