import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    // MARK: - Preview helper

    public static var preview: BibleReaderViewModel {
        // Create a minimal BibleReaderViewModel for preview purposes
        let vm = BibleReaderViewModel(reference: BibleReference(versionId: 3034, bookUSFM: "GEN", chapter: 1))

        let previewVersion = BibleVersion.preview
        vm.version = previewVersion

        let footnoteReference = BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 21, verse: 1)
        vm.footnotesToDisplay = [
            BibleFootnote(text: BibleAttributedString("Footnote text goes here."), reference: footnoteReference, id: "one"),
            BibleFootnote(text: BibleAttributedString("Second Footnote text goes here. This time the footnote is fairly long."), reference: footnoteReference, id: "two")
        ]
        return vm
    }

}
