import SwiftUI
import YouVersionPlatformUI

struct BibleReaderFootnotesView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        let textOptions = BibleTextOptions(
            fontFamily: viewModel.textOptions.fontFamily,
            fontSize: 16,
            lineSpacing: viewModel.textOptions.lineSpacing,
            paragraphSpacing: viewModel.textOptions.paragraphSpacing,
            textColor: viewModel.textOptions.textColor,
            verseNumColor: viewModel.textOptions.verseNumColor,
            wocColor: viewModel.textOptions.wocColor,
            renderHeadlines: false,
            renderVerseNumbers: false,
            footnoteMode: .letters,
            footnoteMarker: nil,
        )

        return VStack(alignment: .leading) {
            if let version = viewModel.version,
                let reference = viewModel.footnotesToDisplay.first?.reference {
                Text(version.displayTitle(for: reference))
                    .font(ReaderFonts.fontHeaderS)
                    .padding(.bottom)
                ScrollView {
                    BibleTextView(reference, textOptions: textOptions)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom)
                    Divider()
                    VStack(alignment: .leading) {
                        ForEach(Array(viewModel.footnotesToDisplay.enumerated()), id: \.offset) { index, footnote in
                            let character = String(UnicodeScalar(97 + (index % 26))!)
                            let txt = footnote.text.setFont(.footnote, from: BibleTextFonts(familyName: "San Francisco", baseSize: 15))
                            HStack(alignment: .firstTextBaseline) {
                                Text(character + ".")
                                    .font(ReaderFonts.fontLabelS)
                                Text(txt.asAttributedString)
                                    .multilineTextAlignment(.leading)
                            }
                            Divider()
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
    
}

#Preview {
    BibleReaderFootnotesView()
        .environment(BibleReaderViewModel.preview)
}
