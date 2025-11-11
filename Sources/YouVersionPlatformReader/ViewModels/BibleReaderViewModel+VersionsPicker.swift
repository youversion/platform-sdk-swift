import SwiftUI
import YouVersionPlatformCore

extension BibleReaderViewModel {

    // MARK: - VersionsPicker functions, for Version selection and manipulation

    func versionsStackPush(to screen: VersionsPickerScreen) {
        versionsPickerStack.append(screen)
        showingVersionsStack = true
    }

    func versionsStackPop() {
        guard !versionsPickerStack.isEmpty else {
            showingVersionsStack = false
            return
        }
        versionsPickerStack.removeLast()
    }

    func handlePickersVersionTap() {
        loadVersionsList()
        chosenLanguage = nil  // reset the search field
        versionsPickerStack.removeAll()
        showingVersionsStack = true
    }

    func versionInfoSheetAdd() {
        if let selectedVersion {
            myVersions.insert(selectedVersion)
        }
    }

    func versionInfoSheetAdded() {
        if let selectedVersion {
            myVersions.remove(selectedVersion)
        }
    }

    func versionInfoSheetBack() {
        versionsStackPop()
    }

    func versionInfoSheetDownload() {
        if let selectedVersion {
            conditionalDownloadButtonTapped(version: selectedVersion)
        }
    }

    func versionInfoSheetRead() {
        if let id = selectedVersion?.id {
            switchToVersion(id)
            showingVersionsStack = false
        }
    }

    func versionInfoSheetSample() {
        versionInfoSheetRead()
    }
}
