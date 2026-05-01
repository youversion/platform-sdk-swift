import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderIntroView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var html: String?
    
    public var body: some View {
        VStack {
            if let html {
                BibleTextView(
                    html: html,
                    reference: viewModel.reference,
                    textOptions: viewModel.textOptions,
                    onVerseTap: { reference, actionType, footnotes, footnoteId in
                        let thisNote = footnotes.filter { $0.id == footnoteId }
                        viewModel.footnotesToDisplay = thisNote.isEmpty ? footnotes : thisNote
                        viewModel.showingIntroFootnoteSheet = true
                    }
                )
            } else {
                ProgressView()
            }
        }
        .onChange(of: viewModel.reference, initial: true) { _, reference in
            self.html = nil
            Task {
                if let book = viewModel.version?.book(with: reference.bookUSFM),
                   let passageId = book.intro?.passageId,
                   let html = try? await YouVersionAPI.Bible.introMaterial(versionId: reference.versionId, passageId: passageId) {
                    self.html = html
                } else {
                    self.html = "<div>Error loading Intro</div>"
                }
            }
        }
    }
}
