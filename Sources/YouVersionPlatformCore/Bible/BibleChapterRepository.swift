import Foundation
//import ZipArchive // TEMPORARY
// #if canImport(ZipArchive)
// import ZipArchive
// #elseif canImport(SSZipArchive)
// import SSZipArchive
// #endif

func urlForBibleContentDirectory(versionId: Int, kind: FileManager.SearchPathDirectory) -> URL {
    let cachesDirectory = FileManager.default.urls(for: kind, in: .userDomainMask).first!
    return cachesDirectory
        .appending(path: "bible_\(versionId)", directoryHint: .isDirectory)
}

public actor ChapterDiskCache {
    static func urlForChaptersDirectory(versionId: Int) -> URL {
        urlForBibleContentDirectory(versionId: versionId, kind: .cachesDirectory)
            .appending(path: "Chapters", directoryHint: .isDirectory)
    }

    static func urlForCachedChapter(withUSFM usfm: String, versionId: Int) -> URL {
        urlForChaptersDirectory(versionId: versionId)
            .appending(path: usfm, directoryHint: .notDirectory)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        guard let chapterUSFM = reference.chapterUSFM else {
            return nil
        }
        let url = Self.urlForCachedChapter(withUSFM: chapterUSFM, versionId: reference.versionId)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func addChapterContent(_ content: String, reference: BibleReference) {
        guard let chapterUSFM = reference.chapterUSFM else {
            return
        }
        let url = Self.urlForCachedChapter(withUSFM: chapterUSFM, versionId: reference.versionId)
        do {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = content.data(using: .utf8) {
                try data.write(to: url, options: .atomic)
            } else {
                print("WARNING: Failed to convert content to UTF-8 data for \(url)")
            }
        } catch {
            print("WARNING: ChapterDiskCache failed to write data to \(url): \(error)")
        }
    }

    public func removeVersion(versionId: Int) async {
        let cacheURL = Self.urlForChaptersDirectory(versionId: versionId)
        do {
            try FileManager.default.removeItem(at: cacheURL)
            print("removed \(cacheURL.path())")
        } catch {
            print("ChapterDiskCache got error while removing: \(error.localizedDescription)")
        }
    }
}

// TODO: this code is nearly identical to VersionDiskCache, but we can't inherit from an actor. DRY this.
// (Plus, both of these are nearly identical to the code of VersionDiskCache and VersionDownloadCache!)
public actor ChapterDownloadCache {
    static func urlForChaptersDirectory(versionId: Int) -> URL {
        urlForBibleContentDirectory(versionId: versionId, kind: .applicationSupportDirectory)
            .appending(path: "Chapters", directoryHint: .isDirectory)
    }

    static func urlForCachedChapter(withUSFM usfm: String, versionId: Int) -> URL {
        urlForChaptersDirectory(versionId: versionId)
            .appending(path: usfm, directoryHint: .notDirectory)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        guard let chapterUSFM = reference.chapterUSFM else {
            return nil
        }
        let url = Self.urlForCachedChapter(withUSFM: chapterUSFM, versionId: reference.versionId)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /* TEMPORARY
    func addChapterContent(_ content: String, reference: BibleReference) {
        guard let chapterUSFM = reference.chapterUSFM else {
            return
        }
        let url = Self.urlForCachedChapter(withUSFM: chapterUSFM, versionId: reference.versionId)
        do {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = content.data(using: .utf8) {
                try data.write(to: url, options: .atomic)
            } else {
                print("WARNING: Failed to convert content to UTF-8 data for \(url)")
            }
        } catch {
            print("WARNING: ChapterDownloadCache failed to write data to \(url): \(error)")
        }
    }

    /// Downloads and installs a complete version bundle
    func downloadVersionBundle(versionId: Int, build: Int, accessToken: String) async throws {
        guard let appKey = YouVersionPlatformConfiguration.appKey else {
            fatalError("YouVersionPlatformConfiguration.appKey must be set.")
        }

        let host = YouVersionPlatformConfiguration.apiHost
        let url = URL(string: "https://\(host)/bible/bundle?version=\(versionId)&build=\(build)")!
        var request = URLRequest(url: url)
        request.setValue(appKey, forHTTPHeaderField: "x-yvp-app-key")
        request.setValue(YouVersionPlatformConfiguration.installId, forHTTPHeaderField: "x-yvp-installation-id")
        request.setValue(accessToken, forHTTPHeaderField: "x-yv-lat")

        let (localURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("downloadVersionBundle: unexpected response type")
            throw BibleVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            print("downloadVersionBundle: 401 Unauthorized (possibly a bad appKey, or the user has not granted permission)")
            throw BibleVersionAPIError.notPermitted
        }

        guard httpResponse.statusCode == 200 else {
            print("error \(httpResponse.statusCode) while downloading a version")
            throw BibleVersionAPIError.cannotDownload
        }

        var cacheURL = Self.urlForChaptersDirectory(versionId: versionId)
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)

        SSZipArchive.unzipFile(atPath: localURL.path(), toDestination: cacheURL.path(percentEncoded: false))

        // exclude it from iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? cacheURL.setResourceValues(values)
    }
     */

    nonisolated public func chaptersArePresent(versionId: Int) -> Bool {
        let path = Self.urlForChaptersDirectory(versionId: versionId).path()
        if let contents = FileManager.default.subpaths(atPath: path) {
            return !contents.isEmpty
        }
        return false
    }

    public func removeVersion(versionId: Int) async {
        let cacheURL = Self.urlForChaptersDirectory(versionId: versionId)
        do {
            try FileManager.default.removeItem(at: cacheURL)
        } catch {
            print("ChapterDownloadCache got error while removing: \(error.localizedDescription)")
        }
    }

}

public actor BibleChapterRepository: ObservableObject {

    public static let shared = BibleChapterRepository()

    // TODO: add MRU functionality and a maximum number of entries to this memoryCache.
    private var memoryCache: [String: String] = [:]
    private var diskCache = ChapterDiskCache()
    private var downloadCache = ChapterDownloadCache()

    static func cacheKey(reference: BibleReference) -> String {
        "\(reference.versionId)_\(reference.chapterUSFM ?? "unknown")"
    }

    func removeChaptersFromMemoryCache(withId versionId: Int) {
        let prefix = "\(versionId)_"
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
    }

    public func chapter(withReference reference: BibleReference) async throws -> String {
        let cacheKey = Self.cacheKey(reference: reference)

        if let cachedContent = memoryCache[cacheKey] {
            print("found in memoryCache: \(cacheKey)")
            return cachedContent
        }

        if let cachedContent = await diskCache.chapterContent(withReference: reference) {
            print("found in diskCache: \(cacheKey)")
            memoryCache[cacheKey] = cachedContent
            return cachedContent
        }

        if let cachedContent = await downloadCache.chapterContent(withReference: reference) {
            print("found in downloadCache: \(cacheKey)")
            memoryCache[cacheKey] = cachedContent
            return cachedContent
        }

        let content = try await YouVersionAPI.Bible.chapter(reference: reference)

        memoryCache[cacheKey] = content
        await diskCache.addChapterContent(content, reference: reference)

        return content
    }

    func cachedChapter(withReference reference: BibleReference) throws -> String? {
        let cacheKey = Self.cacheKey(reference: reference)
        return memoryCache[cacheKey]
    }

    /* TEMPORARY
    public func download(version: BibleVersion) async throws {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            print("download: not logged in")
            throw BibleVersionAPIError.notPermitted
        }
        guard let build = version.offline?.build?.max else {
            print("no build info")
            throw BibleVersionAPIError.cannotDownload
        }
        do {
            try await downloadCache.downloadVersionBundle(
                versionId: version.id,
                build: build,
                accessToken: accessToken
            )
        } catch {
            print("download failed: \(error)")
            throw error
        }
        await diskCache.removeVersion(versionId: version.id)  // no need to keep 2 copies
    }*/

    func chaptersArePresent(versionId: Int) -> Bool {
        downloadCache.chaptersArePresent(versionId: versionId)
    }

    @MainActor
    public func removeVersion(withId versionId: Int) async {
        await removeChaptersFromMemoryCache(withId: versionId)
        await diskCache.removeVersion(versionId: versionId)
        await downloadCache.removeVersion(versionId: versionId)
    }
}
