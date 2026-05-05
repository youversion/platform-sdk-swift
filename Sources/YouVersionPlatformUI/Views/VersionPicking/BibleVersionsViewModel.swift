import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore

@MainActor
@Observable
public final class BibleVersionsViewModel {
    /// The currently selected Bible version. Observe this property to react
    /// when the user picks a version (either at initial load or from the
    /// version picker UI).
    public private(set) var currentVersion: BibleVersion?

    @available(*, deprecated, message: "Observe currentVersion instead.")
    public var onVersionChange: ((BibleVersion) -> Void) {
        get { _onVersionChange }
        set { _onVersionChange = newValue }
    }

    @ObservationIgnored
    private var _onVersionChange: (BibleVersion) -> Void

    /// called when the user chooses to download a version and they're not yet signed in.
    public var onSignInRequired: (() -> Void)?
    public var colorTheme: ReaderTheme?

    public let versionRepository: any BibleVersionRepositoryProtocol

    var currentBibleVersionLanguage: String?
    var showGenericAlert = false
    var textForGenericAlertTitle = ""
    var textForGenericAlertBody = ""
    private(set) var textForGenericAlertOKButton = String.localized("generic.ok")
    
    private let userDefaultsKeyForMyVersions = "bible-reader-view--my-versions"
    private var hasLoadedInitialState = false

    /// Creates a Bible versions view model.
    ///
    /// Observe ``currentVersion`` to react when a version is selected.
    public init(
        versionRepository: any BibleVersionRepositoryProtocol = BibleVersionRepository.shared
    ) {
        self.myVersions = []
        self.suggestedLanguages = []
        self._onVersionChange = { _ in }
        self.versionRepository = versionRepository
    }

    @available(*, deprecated, message: "Use init(versionRepository:) and observe currentVersion instead.")
    public convenience init(
        onVersionChange: @escaping (BibleVersion) -> Void,
        versionRepository: any BibleVersionRepositoryProtocol = BibleVersionRepository.shared
    ) {
        self.init(versionRepository: versionRepository)
        self._onVersionChange = onVersionChange
    }

    /// Sets the current version and fires the deprecated ``onVersionChange``
    /// callback for callers that haven't migrated to observing ``currentVersion``.
    func setCurrentVersion(_ version: BibleVersion) {
        currentVersion = version
        _onVersionChange(version)
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
        guard let permitted = await permittedVersions() else {
            return  // when offline, we don't get a list, but don't delete anything!
        }
        let permittedIds = Set(permitted.map(\.id))
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
            setCurrentVersion(version)
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
        setCurrentVersion(version)

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
    
    /// Maps from a language tag to a list of BibleVersion objects for that language.
    var versionsByLanguageTag: [String: [BibleVersion]] = [:]
    
    /// Holds minimal information about all Bible versions available to this app, in all languages.
    private(set) var cachedPermittedVersions: [YouVersionAPI.Bible.BibleVersionMinimalInfo]?
    
    /// Returns minimal information about all Bible versions available to this app, in all languages.
    /// On error or when offline, returns nil
    func permittedVersions() async -> [YouVersionAPI.Bible.BibleVersionMinimalInfo]? {
        if let cachedPermittedVersions {
            return cachedPermittedVersions
        }
        
        let versions = try? await YouVersionAPI.Bible.permittedVersions(forLanguageTag: nil)

        if let versions, cachedPermittedVersions == nil {
            cachedPermittedVersions = versions
        }
        return versions
    }
    
    private var languageTagsBeingFetched: Set<String> = []
    
    /// Causes data to be fetched, if necessary, to fill out `versionsByLanguageTag` for the given language tag.
    /// The fetch happens in a separate task. UI should observe `versionsByLanguageTag` and update when it does.
    func fetchVersions(forLanguageTag languageTag: String) {
        guard versionsByLanguageTag[languageTag] == nil else {
            return  // no need to fetch: we already have the data
        }
        guard !languageTagsBeingFetched.contains(languageTag) else {
            return
        }
        languageTagsBeingFetched.insert(languageTag)
        Task {
            if let unsortedVersions = try? await YouVersionAPI.Bible.versions(forLanguageTag: languageTag) {
                let sortedVersions = unsortedVersions.sorted {
                    let a = $0.localizedTitle ?? $0.title ?? $0.localizedAbbreviation ?? $0.abbreviation ?? String($0.id)
                    let b = $1.localizedTitle ?? $1.title ?? $1.localizedAbbreviation ?? $1.abbreviation ?? String($1.id)
                    return a < b
                }
                versionsByLanguageTag[languageTag] = sortedVersions
            }
            languageTagsBeingFetched.remove(languageTag)
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
    
    private(set) var suggestedLanguages: [LanguageOverview]
    var chosenLanguage: String?
    var languageNames: [String: String] = [:]
    
    private func loadSuggestedLanguages() async {
        let region = Locale.current.region?.identifier ?? "US"
        do {
            suggestedLanguages = try await YouVersionAPI.Languages.languages(country: region, fields: ["language", "display_names"])
        } catch {
            YouVersionPlatformLogger.error("Error fetching languages: \(error.localizedDescription)", category: "Reader")
        }
    }
    
    /// Language tags likely to be ones the user will want. Doesn't return any for which we have no Bible versions.
    var suggestedLanguageTags: [String] {
        guard !suggestedLanguages.isEmpty else {
            return ["en", "es"]
        }
        let tags = uniqueLanguageTags(from: suggestedLanguages)
        guard let versionsInfo = cachedPermittedVersions else {
            return tags
        }
        let ret = tags.filter { tag in
            versionsInfo.isEmpty || versionsInfo.contains(where: { $0.languageTag == tag })
        }
        return ret
    }

    func languageName(_ lang: String) -> String {
        languageNames[lang] ?? Locale.current.localizedString(forLanguageCode: lang) ?? lang
    }

    /// Returns deduplicated language tags from the list, preserving order.
    private func uniqueLanguageTags(from languages: [LanguageOverview]) -> [String] {
        let languageTags = languages.compactMap { $0.language }

        var seen = Set<String>()
        return languageTags.filter { languageTag in
            if seen.contains(languageTag) {
                return false
            } else {
                seen.insert(languageTag)
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
    
    private var organizationsById: [String: Organization] = [:]
    
    func organizationName(id: String) -> String? {
        guard let org = organizationsById[id] else {
            Task {
                if let data = try? await YouVersionAPI.Organizations.organization(id: id) {
                    organizationsById[id] = data
                }
            }
            return nil
        }
        return org.name
    }
    
    // MARK: - Preview helper

    public static var preview: BibleVersionsViewModel {
        // Create a minimal BibleVersionsViewModel for preview purposes
        let vm = BibleVersionsViewModel()

        let previewVersion = BibleVersion.preview
        vm.myVersions = [previewVersion]
        vm.selectedVersion = previewVersion
        vm.switchToVersion(previewVersion)

        return vm
    }
}
