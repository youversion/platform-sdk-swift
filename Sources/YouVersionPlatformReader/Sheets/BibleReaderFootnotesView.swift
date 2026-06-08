import SwiftUI
import YouVersionPlatformUI

struct BibleReaderFootnotesView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var footnotes: [BibleFootnote] = []

    var body: some View {
        VStack(alignment: .leading) {
            if let version = viewModel.version,
                let reference = viewModel.footnotesToDisplay.first?.reference {
                Text(version.displayTitle(for: reference))
                    .font(YouVersionFonts.headerSmall)
                    .padding(.bottom)
                ScrollView {
                    BibleTextView(reference, textOptions: textOptions)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom)
                    Divider()
                        .padding(.bottom, 8)
                    VStack(alignment: .leading) {
                        ForEach(Array(footnotes.enumerated()), id: \.offset) { index, footnote in
                            let character = String(UnicodeScalar(97 + (index % 26))!)
                            HStack(alignment: .firstTextBaseline) {
                                Text(character + ".")
                                    .font(YouVersionFonts.labelSmall)
                                Text(footnote.text.asAttributedString)
                                    .multilineTextAlignment(.leading)
                            }
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .task {
            // We prefer not to display viewModel.footnotes[] since it is in the user's
            // Bible font family and size, which might look odd in the context of this view.
            let textOptions = self.textOptions
            if let reference = viewModel.footnotesToDisplay.first?.reference,
               let blocks = try? await BibleVersionRendering.textBlocks(
                reference: reference,
                renderHeadlines: textOptions.renderHeadlines,
                renderVerseNumbers: textOptions.renderVerseNumbers,
                footnotesMode: textOptions.footnoteMode,
                footnoteMarker: textOptions.footnoteMarker,
                textColor: textOptions.textColor ?? Color.primary,
                verseNumColor: textOptions.verseNumberColor ?? Color.secondary,
                wocColor: textOptions.textColor ?? Color.primary,
                fonts: BibleTextFonts(familyName: textOptions.fontFamily, baseSize: textOptions.fontSize)
               ) {
                self.footnotes = blocks.flatMap(\.footnotes).filter { $0.reference == reference }
            } else {
                self.footnotes = viewModel.footnotesToDisplay
            }
        }
    }
    
    var textOptions: BibleTextOptions {
        BibleTextOptions(
            fontFamily: "Untitled Serif",
            fontSize: 16,
            lineSpacing: 0.4,
            paragraphSpacing: 0,
            renderHeadlines: false,
            renderVerseNumbers: false,
            footnoteMode: .letters,
            footnoteMarker: nil,
        )
    }
    
}

#Preview {
    BibleReaderFootnotesView()
        .environment(BibleReaderViewModel.preview)
}
