import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore

@MainActor
@Observable
public final class BibleVersionsViewModel {
    public var onVersionChange: ((BibleVersion) -> Void)
    /// called when the user chooses to download a version and they're not yet signed in.
    public var onSignInRequired: (() -> Void)?
    public var colorTheme: ReaderTheme?

    public let versionRepository: any BibleVersionRepositoryProtocol

    var currentBibleVersionLanguage: String?
    var showGenericAlert = false
    var textForGenericAlertTitle = ""
    var textForGenericAlertBody = ""
    private(set) var textForGenericAlertOKButton = "OK"
    
    private let userDefaultsKeyForMyVersions = "bible-reader-view--my-versions"
    private var hasLoadedInitialState = false

    /// onVersionChange: called when the user has chosen a new version (or their first). The caller should ensure their current reference exists in this new version and choose a new one if not.
    public init(
        onVersionChange: @escaping (BibleVersion) -> Void,
        versionRepository: any BibleVersionRepositoryProtocol = BibleVersionRepository.shared
    ) {
        self.myVersions = []
        self.suggestedLanguagesList = []
        self.onVersionChange = onVersionChange
        self.versionRepository = versionRepository
    }

    /// Loads the initial version data once for this model instance.
    public func loadInitialState(initialVersionId: Int? = nil) async {
        guard !hasLoadedInitialState else {
            return
        }
        hasLoadedInitialState = true

        // Grab the saved data first, because initializing myVersions clears the saved data.
        let savedIds = Set(UserDefaults.standard.array(forKey: userDefaultsKeyForMyVersions) as? [Int] ?? [])

        async let version: Void = loadVersion(versionId: initialVersionId, savedIds: savedIds)
        async let restored: Void = restoreMyVersions(savedIds: savedIds)
        async let suggested: Void = loadSuggestedLanguages()
        _ = await (version, restored, suggested)
        await removeUnpermittedVersions(initialVersionId: initialVersionId)
    }
    
    private func removeUnpermittedVersions(initialVersionId: Int?) async {
        guard let permittedVersions = await permittedVersionsListing() else {
            return  // when offline, we don't get a list, but don't delete anything!
        }
        let permittedIds = Set(permittedVersions.map(\.id))
        await versionRepository.removeUnpermittedVersions(permittedIds: permittedIds)
        
        for version in myVersions where !permittedIds.contains(version.id) {
            myVersions.remove(version)
        }
        if let initialVersionId, !permittedIds.contains(initialVersionId) {
            await selectFallbackVersion(savedIds: Set(myVersions.map(\.id)))
        }
    }
    
    private func restoreMyVersions(savedIds: Set<Int>) async {
        for id in savedIds {
            if let version = try? await versionRepository.versionIfCached(id) {
                myVersions.insert(version)
            }
        }

        // downloaded versions must also be in MyVersions, otherwise they couldn't be deleted.
        for id in BibleVersionRepository.defaultDownloadedVersionIds where !myVersions.contains(where: { $0.id == id }) {
            if let version = try? await versionRepository.versionIfCached(id) {
                myVersions.insert(version)
            }
        }
    }
    
    private func loadVersion(versionId: Int?, savedIds: Set<Int>) async {
        // Resolve the desired version if possible; otherwise fall back once at the end
        var loadedVersion: BibleVersion?

        if let id = versionId {
            do {
                loadedVersion = try await versionRepository.version(withId: id)
            } catch YouVersionAPIError.notPermitted {
                // Leave loadedVersion as nil; we'll fall back below
            } catch {
                YouVersionPlatformLogger.error("Error loading default version: \(error)", category: "Reader")
            }
        }

        if let version = loadedVersion {
            myVersions.insert(version)
            onVersionChange(version)
        } else {
            await selectFallbackVersion(savedIds: savedIds)
        }
    }
    
    private func selectFallbackVersion(savedIds: Set<Int>) async {
        guard let nextBestVersion = await fallbackVersion(savedIds: savedIds),
              let version = try? await versionRepository.version(withId: nextBestVersion)
        else {
            // bring up the UI, let the user choose.
            versionsStackPush(to: .moreVersions)
            return
        }
        onVersionChange(version)

        myVersions.insert(version)
    }
    
    /// Picks a Bible version to fall back to when no specific version is selected,
    /// trying these sources in priority order:
    /// 1. The first version the user has already downloaded.
    /// 2. The first of the user's saved versions that is currently permitted.
    /// 3. The first available English version.
    /// 4. Any available version.
    ///
    /// - Parameter savedIds: IDs of versions the user has previously saved
    ///   (used as a preference at priority step 2).
    /// - Returns: A fallback version ID, or `nil` if no version is available
    ///   (typically because the device is offline).
    private func fallbackVersion(savedIds: Set<Int>) async -> Int? {
        let downloadedVersionIds = BibleVersionRepository.defaultDownloadedVersionIds
        if let downloadedVersionId = downloadedVersionIds.first {
            return downloadedVersionId
        }
        
        if let versions = try? await YouVersionAPI.Bible.versions() {
            // are any of the permitted versions in their myVersions list?
            for version in versions where savedIds.contains(version.id) {
                return version.id
            }
            
            // For now, fall back to a Bible in English.
            // It would be better to search for a bible in the device's language,
            // before defaulting to English.
            if let version = versions.first(where: { $0.languageTag == "en" }) {
                return version.id
            }
            
            if let version = versions.first {
                return version.id
            }
        } else {
            YouVersionPlatformLogger.error("Could not fetch the permitted versions", category: "Reader")
        }
        return nil  // at this point we must be offline or the app has been shut down. Give up.
    }
    
    // MARK: - Versions list
    
    /// Maps from a languageCode to a list of BibleVersion objects for that language.
    var versionsInLanguage: [String: [BibleVersion]] = [:]
    
    /// Holds minimal information about all Bible versions available to this app, in all languages.
    private(set) var permittedVersionsList: [YouVersionAPI.Bible.BibleVersionMinimalInfo]?
    
    /// Returns minimal information about all Bible versions available to this app, in all languages.
    /// On error or when offline, returns nil
    func permittedVersionsListing() async -> [YouVersionAPI.Bible.BibleVersionMinimalInfo]? {
        if let permittedVersionsList {
            return permittedVersionsList
        }
        
        let time1 = Date()
        let versions = try? await YouVersionAPI.Bible.permittedVersions(forLanguageTag: nil)
        let elapsed = Date().timeIntervalSince(time1)
        YouVersionPlatformLogger.debug(
            "fetchBibleVersionMinimalInfo got \(versions?.count ?? -999) in \(String(format: "%.2f", elapsed)) seconds.",
            category: "Reader"
        )
        
        if let versions, permittedVersionsList == nil {
            permittedVersionsList = versions
        }
        return versions
    }
    
    private var versionsBeingFetched: Set<String> = []
    
    /// Causes data to be fetched, if necessary, to fill out `versionsInLanguage` for the given language code.
    /// The fetch happens in a separate task. UI should observe `versionsInLanguage` and update when it does.
    func fetchVersionsInLanguage(code: String) {
        guard versionsInLanguage[code] == nil else {
            return  // no need to fetch: we already have the data
        }
        guard !versionsBeingFetched.contains(code) else {
            return
        }
        versionsBeingFetched.insert(code)
        Task {
            let time1 = Date()
            if let unsortedVersions = try? await YouVersionAPI.Bible.versions(forLanguageTag: code) {
                let elapsed = Date().timeIntervalSince(time1)
                YouVersionPlatformLogger.debug(
                    "fetchVersionsInLanguage('\(code)') got \(unsortedVersions.count) in \(String(format: "%.2f", elapsed)) seconds.",
                    category: "Reader"
                )
                let sortedVersions = unsortedVersions.sorted {
                    let a = $0.localizedTitle ?? $0.title ?? $0.localizedAbbreviation ?? $0.abbreviation ?? String($0.id)
                    let b = $1.localizedTitle ?? $1.title ?? $1.localizedAbbreviation ?? $1.abbreviation ?? String($1.id)
                    return a < b
                }
                versionsInLanguage[code] = sortedVersions
            }
            versionsBeingFetched.remove(code)
        }
    }
    
    var showFullProgressViewOverlay = false
    
    // MARK: - My Versions
    public var myVersions: Set<BibleVersion> = [] {
        didSet {
            Task {
                // The below iteration must be run in a Task to avoid view re-creation loops.
                let ids = myVersions.map { $0.id }
                UserDefaults.standard.set(ids, forKey: userDefaultsKeyForMyVersions)
            }
        }
    }
    
    var showVersionInfoSharingAlert = false
    var showVersionInfoSharingText = ""
    
    // MARK: - Languages picking
    
    private(set) var suggestedLanguagesList: [LanguageOverview]
    var chosenLanguage: String?
    var languageNames: [String: String] = [:]
    
    private func loadSuggestedLanguages() async {
        let region = Locale.current.region?.identifier ?? "US"
        do {
            let time1 = Date()
            suggestedLanguagesList = try await YouVersionAPI.Languages.languages(country: region, fields: ["language", "display_names"])
            let elapsed = Date().timeIntervalSince(time1)
            YouVersionPlatformLogger.debug(
                "loadSuggestedLanguages got \(suggestedLanguagesList.count) in \(String(format: "%.2f", elapsed)) seconds.",
                category: "Reader"
            )
        } catch {
            YouVersionPlatformLogger.error("Error fetching languages: \(error.localizedDescription)", category: "Reader")
        }
    }
    
    /// Returns languages likely to be ones the user will want. Doesn't return any for which we have no Bible versions.
    var suggestedLanguages: [String] {
        guard !suggestedLanguagesList.isEmpty else {
            return ["en", "es"]
        }
        let codes = extractLanguageCodes(languages: suggestedLanguagesList)
        guard let versionsInfo = permittedVersionsList else {
            return codes
        }
        let ret = codes.filter { code in
            versionsInfo.isEmpty || versionsInfo.contains(where: { $0.languageTag == code })
        }
        return ret
    }
    
    func languageName(_ lang: String) -> String {
        languageNames[lang] ?? Locale.current.localizedString(forLanguageCode: lang) ?? lang
    }
    
    /// Returns language codes from the list, preferring the 3-letter language codes
    private func extractLanguageCodes(languages: [LanguageOverview]) -> [String] {
        let languageCodes = languages.compactMap { $0.language }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        return languageCodes.filter { languageCode in
            if seen.contains(languageCode) {
                return false
            } else {
                seen.insert(languageCode)
                return true
            }
        }
    }
    
    // MARK: - VersionsPicker settings, for Version selection and manipulation
    
    enum VersionsPickerScreen: Hashable {
        case myVersions
        case moreVersions
        case versionInfo
        case versionDownload
        case languages
    }
    
    public var showingVersionsStack = false
    var versionsPickerStack: [VersionsPickerScreen] = []
    
    var selectedVersion: BibleVersion?
    
    var organizationInfo: [String: Organization] = [:]
    
    func organizationName(id: String) -> String? {
        guard let org = organizationInfo[id] else {
            Task {
                if let data = try? await YouVersionAPI.Organizations.organization(id: id) {
                    organizationInfo[id] = data
                }
            }
            return nil
        }
        return org.name
    }
    
    // MARK: - Preview helper

    public static var preview: BibleVersionsViewModel {
        // Create a minimal BibleVersionsViewModel for preview purposes
        let vm = BibleVersionsViewModel { _ in }

        let previewVersion = BibleVersion.preview
        vm.myVersions = [previewVersion]
        vm.selectedVersion = previewVersion

        return vm
    }
}
