import SwiftUI
import YouVersionPlatformUI

struct BibleReaderIntroFootnoteView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(String.localized("reader.footnoteTitle"))
                    .font(YouVersionFonts.headerSmall)
                    .padding(.bottom)
                ForEach(Array(viewModel.footnotesToDisplay.enumerated()), id: \.offset) { index, footnote in
                    let txt = footnote.text.setFont(.footnote, from: BibleTextFonts(familyName: "San Francisco", baseSize: 15))
                    Text(txt.asAttributedString)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(8)
                        .padding(.bottom)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
    
}

#Preview {
    BibleReaderIntroFootnoteView()
        .environment(BibleReaderViewModel.preview)
}
