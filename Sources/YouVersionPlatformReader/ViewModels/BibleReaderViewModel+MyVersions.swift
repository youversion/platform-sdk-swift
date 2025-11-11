import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {

    public func myVersionItemTapped(_ versionId: Int) {
        switchToVersion(versionId)
        showingVersionsStack = false
    }

    public func myVersionMoreInfoMenuTapped(_ versionId: Int) {
        Task {
            selectedVersion = try await versionRepository.version(withId: versionId)
            versionsStackPush(to: .versionInfo)
        }
    }

    public func finalDownloadButtonTapped(version: BibleVersion) {
        initiateDownload(of: version)
        switchToVersion(version.id)
        showingVersionsStack = false
    }

    public func conditionalDownloadButtonTapped(version: BibleVersion) {
        if version.requiresEmailAgreement == true {
            selectedVersion = version
            versionsStackPush(to: .versionDownload)
        } else {
            finalDownloadButtonTapped(version: version)
        }
    }

    public func myVersionDownloadMenuTapped(_ versionId: Int) {
        Task {
            if let version = try? await versionRepository.version(withId: versionId) {
                conditionalDownloadButtonTapped(version: version)
            } else {
                showGenericAlert = true
                textForGenericAlertTitle = .localized("generic.error")
                textForGenericAlertBody = .localized("myVersions.downloadErrorBody")
            }
        }
    }

    public func myVersionRemoveDownloadMenuTapped(_ versionId: Int) {
        Task {
            await versionRepository.removeVersion(withId: versionId)
            // no need to do the following, as versionRepository handles it:
            //try await BibleChapterRepository.shared.removeVersion(version: version)
        }
    }

    public func myVersionRemoveVersionMenuTapped(_ versionId: Int) {
        if let version = myVersions.first(where: { $0.id == versionId }) {
            myVersions.remove(version)
        }
    }

    public func versionDownloadInfoButtonTapped(for version: BibleVersion) {
        // TODO: get this data, once we have an API to do so
        showVersionInfoSharingText = .localized("myVersions.versionInfoComingSoon")
        showVersionInfoSharingAlert = true
    }

    public func versionDownloadViewBack() {
        versionsStackPop()
    }

    public func versionDownloadViewAccepted(for version: BibleVersion) {
        if !isSignedIn {
            startSignInFlow = true
        } else {
            finalDownloadButtonTapped(version: version)
        }
    }

    public func versionDownloadViewDismissed(for version: BibleVersion) {
        switchToVersion(version.id)
        showingVersionsStack = false
    }

    func initiateDownload(of version: BibleVersion) {
        Task {
            do {
                try await versionRepository.downloadVersion(withId: version.id)
                // TEMPORARY removal
                //try await BibleChapterRepository.shared.download(version: version)
                showGenericAlert = true
                textForGenericAlertTitle = .localized("myVersions.downloadCompleteTitle")
                let versionName = version.localizedTitle ?? .localized("myVersions.defaultVersionName")
                textForGenericAlertBody = String(format: .localized("myVersions.downloadCompleteBodyFormat"), versionName)
            } catch {
                showGenericAlert = true
                textForGenericAlertTitle = .localized("myVersions.downloadFailedTitle")
                let versionName = version.localizedTitle ?? .localized("myVersions.defaultVersionName")
                textForGenericAlertBody = String(
                    format: .localized("myVersions.downloadFailedBodyFormat"),
                    versionName,
                    error.localizedDescription
                )
            }
        }
    }

}
