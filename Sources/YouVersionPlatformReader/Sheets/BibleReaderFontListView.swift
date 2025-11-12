import SwiftUI
import YouVersionPlatformCore

struct BibleReaderFontListView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        VStack {
            ZStack {
                Text(String.localized("fontList.title"))
                    .font(.headline)
                HStack {
                    Button {
                        viewModel.showingFontList = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .padding()
                    Spacer()
                }
            }
            .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading) {
                    Text(String.localized("fontList.suggested"))
                        .font(ReaderFonts.fontHeaderM)
                    fontList(for: ReaderFonts.suggestedFamilies)
                    Divider()
                        .padding(.bottom, 8)
                    Text(String.localized("fontList.others"))
                        .font(ReaderFonts.fontHeaderM)
                    fontList(for: ReaderFonts.otherFamilies)
                }
                .padding(.horizontal)
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
    }

    @ViewBuilder
    private func fontList(for fontFamilies: [String]) -> some View {
        ForEach(fontFamilies, id: \.self) { family in
            Button {
                viewModel.setFont(family: family)
            } label: {
                let isSelected = viewModel.textOptions.fontFamily == family
                HStack {
                    Text(family)
                        .font(.custom(family, size: 20))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.leading)
                    }
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    isSelected ? surfacePrimaryColor : viewModel.readerCanvasPrimaryColor
                )
            }
        }
    }
}

#Preview {
    BibleReaderFontListView()
        .environment(BibleReaderViewModel.preview)
}
