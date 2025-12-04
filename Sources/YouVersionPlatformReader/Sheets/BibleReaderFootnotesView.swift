import SwiftUI
import YouVersionPlatformUI

struct BibleReaderFootnotesView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        // TODO add the renderHeadlines option and turn it off here
        // TODO add a footnoteMode to do superscript letters ("a", "b"...)
        var textOptions = BibleTextOptions(
            fontFamily: viewModel.textOptions.fontFamily,
            fontSize: viewModel.textOptions.fontSize,
            lineSpacing: viewModel.textOptions.lineSpacing,
            paragraphSpacing: viewModel.textOptions.paragraphSpacing,
            textColor: viewModel.textOptions.textColor,
            wocColor: viewModel.textOptions.wocColor,
            renderVerseNumbers: false,
            footnoteMode: viewModel.textOptions.footnoteMode,
            footnoteMarker: viewModel.textOptions.footnoteMarker
        )

        return VStack(alignment: .leading) {
            if let version = viewModel.version, let reference = viewModel.referenceOfFootnote {
                Text(version.displayTitle(for: reference))
                    .font(ReaderFonts.fontHeaderS)
                    .padding([.top, .bottom])
                BibleTextView(reference, textOptions: textOptions)
                    .padding(.bottom)
                Text("a. 1:3 Something here about this verse and it’s a footnote")
                    .font(ReaderFonts.fontLabelS)
                Divider()
                Text("b. 1:3 Something here about this verse and it’s a footnote")
                    .font(ReaderFonts.fontLabelS)
                Divider()
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

#Preview {
    BibleReaderFootnotesView()
        .environment(BibleReaderViewModel.preview)
}
