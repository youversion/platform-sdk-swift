import SwiftUI
import YouVersionPlatformCore

extension BibleVersionsViewModel {
    public var activeLanguage: String {
        chosenLanguage ?? currentBibleVersionLanguage ?? "en"
    }

    public var bibleVersionStatisticsPromo: String {
        guard let versions = permittedVersionsList, !versions.isEmpty else {
            Task {
                await permittedVersionsListing()
            }
            return ""
        }

        let uniqueLanguages = Set(versions.map { $0.languageTag }).count
        return String(format: .localized("versionList.statisticsFormat"), versions.count, uniqueLanguages)
    }

    @MainActor
    public func downloadStatus(for id: Int) async -> BibleVersionRepository.BibleVersionDownloadStatus {
        if versionRepository.downloadStatus(for: id) == .downloaded {
            return .downloaded
        }
        return .notDownloadable
    }

    public func switchToVersion(_ versionId: Int) {
        Task { await switchToVersion(versionId) }
    }

    func switchToVersion(_ versionId: Int) async {
        do {
            let version = try await versionRepository.version(withId: versionId)
            onVersionChange(version)
        } catch {
            handleVersionLoadingError(error)
        }
    }

    public func handleVersionPickerTap(_ versionId: Int) {
        Task { await handleVersionPickerTap(versionId) }
    }

    func handleVersionPickerTap(_ versionId: Int) async {
        do {
            showFullProgressViewOverlay = true
            defer {
                showFullProgressViewOverlay = false
            }
            let version = try await versionRepository.version(withId: versionId)
            selectedVersion = version
            versionsStackPush(to: .versionInfo)
        } catch {
            handleVersionLoadingError(error)
        }
    }

    private func loadLanguageNames() async {
        guard languageNames.isEmpty else {
            return
        }
        do {
            let languages = try await YouVersionAPI.Languages.languages(fields: ["language", "display_names"])
            var map: [String: String] = [:]
            for language in languages where language.displayNames != nil {
                if let displayNames = language.displayNames,
                   let name = bestDisplayName(for: displayNames),
                   let languageCode = language.language {
                    map[languageCode] = name
                }
            }
            YouVersionPlatformLogger.debug("loadLanguageNames filtered to \(map.count) with displayNames.", category: "Reader")
            languageNames = map
        } catch {
            YouVersionPlatformLogger.error("Error fetching languageNames: \(error.localizedDescription)", category: "Reader")
        }
    }

    public func languageTapped() {
        if permittedVersionsList?.isEmpty ?? true {
            showGenericAlert = true
            textForGenericAlertTitle = .localized("generic.error")
            textForGenericAlertBody = .localized("reader.availableLanguagesErrorBody")
        } else {
            versionsStackPush(to: .languages)
            Task {
                await loadLanguageNames()
            }
        }
    }

    /// Heuristically return the name from the map which is the "closest" for the user.
    private func bestDisplayName(for names: [String: String?]) -> String? {
        if names.isEmpty {
            return nil
        }
        if names.count < 2 {
            return names.first?.value
        }
        let currentLanguage = Locale.current.language.languageCode?.identifier
        if let currentLanguage, let name = names[currentLanguage] {
            return name
        }
        if let bibleLanguage = currentBibleVersionLanguage, let name = names[bibleLanguage] {
            return name
        }
        if let name = names["en"] {
            return name
        }
        return names.first?.value
    }

    func handleVersionLoadingError(_ error: Error) {
        YouVersionPlatformLogger.error("Error loading version: \(error)", category: "Reader")
        showGenericAlert = true
        textForGenericAlertTitle = .localized("generic.error")
        textForGenericAlertBody = .localized("reader.versionAccessErrorBody")
    }
}
