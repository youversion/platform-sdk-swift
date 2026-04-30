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

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor VersionMemoryCache: BibleVersionCaching {
    public init() {}

    private var cache: [Int: BibleVersion] = [:]

    public func version(withId id: Int) async -> BibleVersion? {
        cache[id]
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        false
    }

    public func addVersion(_ version: BibleVersion) async {
        cache[version.id] = version
    }

    public func removeVersion(withId versionId: Int) async {
        cache.removeValue(forKey: versionId)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        cache = cache.filter { permittedIds.contains($0.key) }
    }
}

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor VersionDiskCache: BibleVersionCaching {
    private let inner: BibleVersionDiskCache

    public init() {
        self.inner = BibleVersionDiskCache()
    }

    public func version(withId id: Int) async -> BibleVersion? {
        await inner.version(withId: id)
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        inner.versionIsPresent(for: id)
    }

    public func addVersion(_ version: BibleVersion) async {
        await inner.addVersion(version)
    }

    public func removeVersion(withId versionId: Int) async {
        await inner.removeVersion(withId: versionId)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        await inner.removeUnpermittedVersions(permittedIds: permittedIds)
    }
}

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor VersionDownloadCache: BibleVersionCaching {
    private let inner: BibleVersionDownloadCache

    public init() {
        self.inner = BibleVersionDownloadCache()
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        inner.versionIsPresent(for: id)
    }

    public func version(withId id: Int) async -> BibleVersion? {
        await inner.version(withId: id)
    }

    public func addVersion(_ version: BibleVersion) async {
        await inner.addVersion(version)
    }

    public func removeVersion(withId versionId: Int) async {
        await inner.removeVersion(withId: versionId)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        await inner.removeUnpermittedVersions(permittedIds: permittedIds)
    }

    /// Returns the IDs of Bible versions that have been downloaded for offline use, scanning the default app-support directory.
    public static var downloadedVersions: [Int] {
        BibleVersionDownloadCache.downloadedVersions
    }
}

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor ChapterDiskCache {
    private let inner = BibleChapterDiskCache()

    init() {}

    @available(*, deprecated, message: "Use BibleChapterRepository.removeVersion(withId:) instead.")
    public func removeVersion(versionId: Int) async {
        await inner.removeVersion(withId: versionId)
    }
}

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor ChapterDownloadCache {
    private let inner = BibleChapterDownloadCache()

    init() {}

    nonisolated public func chaptersArePresent(versionId: Int) -> Bool {
        inner.chaptersArePresent(versionId: versionId)
    }

    @available(*, deprecated, message: "Use BibleChapterRepository.removeVersion(withId:) instead.")
    public func removeVersion(versionId: Int) async {
        await inner.removeVersion(withId: versionId)
    }
}
