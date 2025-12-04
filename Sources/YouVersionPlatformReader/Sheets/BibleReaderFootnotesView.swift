import SwiftUI
import YouVersionPlatformUI

struct BibleReaderFootnotesView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        var textOptions = BibleTextOptions(
            fontFamily: ReaderFonts.defaultFontFamily,
            fontSize: ReaderFonts.defaultFontSize * 0.80,
            lineSpacing: viewModel.textOptions.lineSpacing,
            paragraphSpacing: viewModel.textOptions.paragraphSpacing,
            textColor: viewModel.textOptions.textColor,
            wocColor: viewModel.textOptions.wocColor,
            renderHeadlines: false,
            renderVerseNumbers: false,
            footnoteMode: viewModel.textOptions.footnoteMode,  // TODO add a footnoteMode to do superscript letters ("a", "b"...)
            footnoteMarker: viewModel.textOptions.footnoteMarker
        )

        return VStack(alignment: .leading) {
            if let version = viewModel.version, let reference = viewModel.referenceOfFootnote {
                Text(version.displayTitle(for: reference))
                    .font(ReaderFonts.fontHeaderS)
                    .padding(.bottom)
                ScrollView {
                    HStack {
                        BibleTextView(reference, textOptions: textOptions)
                        Spacer()
                    }
                    .padding(.bottom)
                    Divider()
                    VStack(alignment: .leading) {
                        ForEach(viewModel.footnotesToDisplay, id: \.self) { footnote in
                            Text(footnote.text.asAttributedString)
                                .font(ReaderFonts.fontLabelS)
                                .multilineTextAlignment(.leading)
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
