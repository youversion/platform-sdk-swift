import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {

    public var activeLanguage: String {
        chosenLanguage ?? version?.languageTag ?? "en"
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
        // TEMPORARY
//        if let overview = permittedVersions.first(where: { $0.id == id }) {
//            if overview.downloadable == true {
//                return .downloadable
//            }
//        }
        return .notDownloadable
    }

    public func switchToVersion(_ versionId: Int) {
        Task {
            let ref = BibleReference(versionId: versionId, bookUSFM: reference.bookUSFM, chapter: reference.chapter)
            await onHeaderSelectionChange(ref)
        }
    }

    public func handleVersionPickerTap(_ versionId: Int) {
        Task {
            do {
                showFullProgressViewOverlay = true
                defer {
                    showFullProgressViewOverlay = false
                }
                let version = try await versionRepository.version(withId: versionId)
                selectedVersion = version
                versionsStackPush(to: .versionInfo)
            } catch {
                print("Error loading version: \(error)")
                showGenericAlert = true
                textForGenericAlertTitle = .localized("generic.error")
                textForGenericAlertBody = "It was not possible to access this Bible version. Please try again later."
            }
        }
    }

    private func loadLanguageNames() async {
        guard languageNames.isEmpty else {
            return
        }
        do {
            let time1 = Date()
            let languages = try await YouVersionAPI.Languages.languages(fields: ["language", "display_names"])
            let elapsed = Date().timeIntervalSince(time1)
            print("loadLanguageNames got \(languages.count) in \(String(format: "%.2f", elapsed)) seconds.")
            var map: [String: String] = [:]
            for language in languages where language.displayNames != nil {
                if let displayNames = language.displayNames,
                   let name = bestDisplayName(for: displayNames),
                   let languageCode = language.language {
                    map[languageCode] = name
                }
            }
            print("loadLanguageNames filtered to \(map.count) with displayNames.")
            languageNames = map
        } catch {
            print("Error fetching languageNames: \(error.localizedDescription)")
        }
    }

    public func languageTapped() {
        if permittedVersionsList == nil || permittedVersionsList!.isEmpty {
            showGenericAlert = true
            textForGenericAlertTitle = .localized("generic.error")
            textForGenericAlertBody = "It was not possible to get the list of available languages. Please try again later."
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
        if let bibleLanguage = version?.languageTag, let name = names[bibleLanguage] {
            return name
        }
        if let name = names["en"] {
            return name
        }
        return names.first?.value
    }

}
