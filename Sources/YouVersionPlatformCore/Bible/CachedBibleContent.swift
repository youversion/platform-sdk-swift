import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CachedBibleContent<Value: Sendable>: Sendable {
    let value: Value
    let expirationDate: Date?
}

struct BibleContentResponse<Value: Sendable>: Sendable {
    let value: Value
    let expirationDate: Date
    let isCacheable: Bool
}

enum BibleContentCachePolicy {
    static let defaultDuration: TimeInterval = 7 * 24 * 60 * 60
}

extension HTTPURLResponse {
    var allowsCaching: Bool {
        !cacheControlDirectives.contains(where: {
            let directiveName = $0.split(separator: "=", maxSplits: 1).first?.lowercased()
            return directiveName == "no-cache" || directiveName == "no-store"
        })
    }

    func cacheExpirationDate(currentDate: Date = Date()) -> Date {
        let maxAge = cacheControlDirectives
            .first { $0.lowercased().hasPrefix("max-age=") }?
            .split(separator: "=", maxSplits: 1)
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        let maximumAge: TimeInterval
        if let maxAge, let parsedMaximumAge = TimeInterval(maxAge), parsedMaximumAge >= 0 {
            maximumAge = parsedMaximumAge
        } else {
            maximumAge = BibleContentCachePolicy.defaultDuration
        }

        let responseAge = value(forHTTPHeaderField: "Age")
            .flatMap(TimeInterval.init) ?? 0
        let remainingLifetime = max(0, maximumAge - max(0, responseAge))
        return currentDate.addingTimeInterval(remainingLifetime)
    }

    private var cacheControlDirectives: [String] {
        value(forHTTPHeaderField: "Cache-Control")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
    }
}
