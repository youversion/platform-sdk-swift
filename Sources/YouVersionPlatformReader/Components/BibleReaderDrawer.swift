import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderDrawer: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    private let buttonHeight = CGFloat(55)

    var body: some View {
        VStack {
            Divider()
            Rectangle()
                .frame(width: 30, height: 2)
                .padding(.top, 4)
                .padding(.bottom, 8)
            ScrollView([.horizontal], showsIndicators: false) {
                HStack {
                    if YouVersionAPI.isSignedIn {
                        highlightColorButtons
                    }
#if !os(tvOS)
                    copyButton
                    if let (url, title) = viewModel.shareableURLAndTitleForSelection {
                        ShareLink(item: url, message: Text(title)) {
                            drawerButtonView(imageName: "square.and.arrow.up", text: .localized("verseActions.share"))
                        }
                    }
#endif
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
        .foregroundStyle(viewModel.readerTextMutedColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }
    
    private var highlightColors: [Color] {
        [
            Color(hex: "fffe00"),
            Color(hex: "5DFF79"),
            Color(hex: "00D6FF"),
            Color(hex: "FFC66F"),
            Color(hex: "FF95EF")
        ]
    }

    private var highlightColorButtons: some View {
        let colorsToRemove = highlightColors.filter(viewModel.isColorPresentOnAnySelectedVerses)
        let colorsToAdd = highlightColors.filter { !viewModel.isColorPresentOnAllSelectedVerses($0) }
        return HStack {
            ForEach(colorsToRemove, id: \.self) { color in
                Button(action: { viewModel.removeVerseColor(color) }) {
                    coloredCircle(with: color)
                        .overlay(
                            Image(systemName: "xmark")
                        )
                }
            }
            ForEach(colorsToAdd, id: \.self) { color in
                Button(action: { viewModel.addVerseColor(color) }) {
                    coloredCircle(with: color)
                }
            }
        }
        .padding(.horizontal)
        .frame(height: buttonHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(viewModel.readerSurfaceTertiaryColor))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
    }

    private func coloredCircle(with color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay(
                Circle().strokeBorder(Color(hex: "#121212").opacity(0.2), lineWidth: 1)
            )
            .frame(width: 36, height: 36)
    }

    private func drawerButtonView(imageName: String, text: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: imageName)
                .padding(.bottom, 6)
            Text(text)
        }
        .padding(.horizontal, 12)
        .frame(height: buttonHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(viewModel.readerSurfaceTertiaryColor))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .font(YouVersionFonts.labelMedium)
    }

    private func drawerButton(imageName: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            drawerButtonView(imageName: imageName, text: text)
        }
    }

    var copyButton: some View {
        drawerButton(imageName: "square.on.square", text: .localized("verseActions.copy")) {
            viewModel.handleVerseActionCopy()
        }
    }
}

#Preview {
    BibleReaderDrawer()
        .environment(BibleReaderViewModel.preview)
}
