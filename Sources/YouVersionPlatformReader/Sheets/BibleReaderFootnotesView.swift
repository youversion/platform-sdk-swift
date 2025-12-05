import SwiftUI
import YouVersionPlatformUI

struct BibleReaderFootnotesView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        let textOptions = BibleTextOptions(
            fontFamily: ReaderFonts.defaultFontFamily,
            fontSize: ReaderFonts.defaultFontSize * 0.80,
            lineSpacing: viewModel.textOptions.lineSpacing,
            paragraphSpacing: viewModel.textOptions.paragraphSpacing,
            textColor: viewModel.textOptions.textColor,
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
                        ForEach(viewModel.footnotesToDisplay.indices, id: \.self) { index in
                            let footnote = viewModel.footnotesToDisplay[index]
                            HStack(alignment: .firstTextBaseline) {
                                let character = String(UnicodeScalar(UnicodeScalar("a").value + UInt32(index)) ?? " ")
                                Text(character + ".")
                                Text(footnote.text.asAttributedString)
                                    .multilineTextAlignment(.leading)
                            }
                            .font(ReaderFonts.fontLabelS)
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
