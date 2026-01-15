import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {

    public var activeLanguage: String {
        chosenLanguage ?? version?.languageTag ?? "en"
    }

    public var bibleVersionStatisticsPromo: String {
        guard let versions = minimalPermittedVersionsInfo, !versions.isEmpty else {
            Task {
                await fetchBibleVersionMinimalInfo()
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

}
