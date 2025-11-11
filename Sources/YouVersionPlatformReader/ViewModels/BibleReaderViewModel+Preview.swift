import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    // MARK: - Preview helper

    public static var preview: BibleReaderViewModel {
        // Create a minimal BibleReaderViewModel for preview purposes
        let vm = BibleReaderViewModel(reference: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1))
        vm.permittedVersions = [BibleVersion.preview]

        let previewVersion = BibleVersion.preview
        vm.version = previewVersion
        vm.myVersions = [previewVersion]
        vm.selectedVersion = previewVersion
        return vm
    }

}
