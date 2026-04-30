import Foundation

// MARK: - Deprecated public surface
//
// The types and members in this file existed in earlier releases as part of
// the public SDK surface but are no longer used internally. They are kept
// here only so existing call sites continue to compile and link. New code
// should not reference any of them — they will be removed at the next
// major version bump.

@available(*, deprecated, message: "Internal SDK type. This protocol will be removed in a future major version.")
public protocol BibleVersionAPIClient: Sendable {
    func version(withId id: Int) async throws -> BibleVersion
}

@available(*, deprecated, message: "Internal SDK type. This protocol will be removed in a future major version.")
public protocol BibleVersionCaching: Sendable {
    func version(withId id: Int) async -> BibleVersion?
    func addVersion(_ version: BibleVersion) async
    func removeVersion(withId versionId: Int) async
    func versionIsPresent(for id: Int) -> Bool
    func removeUnpermittedVersions(permittedIds: Set<Int>) async
}

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public final class VersionClient: BibleVersionAPIClient {
    public init() {}

    public func version(withId id: Int) async throws -> BibleVersion {
        try await YouVersionAPI.Bible.version(versionId: id)
    }
}
