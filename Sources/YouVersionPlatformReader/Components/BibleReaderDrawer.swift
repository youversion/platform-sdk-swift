import SwiftUI

struct BibleReaderDrawer: View, ReaderColors {
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
                    highlightColorButtons
                    copyButton
                    if let (url, title) = viewModel.shareableURLAndTitleForSelection {
                        ShareLink(item: url, message: Text(title)) {
                            drawerButtonView(imageName: "square.and.arrow.up", text: .localized("verseActions.share"))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
            //swipeUpLabel  // uncomment this once we support swipe, and have something to show!
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
        HStack {
            ForEach(highlightColors, id: \.self) { color in
                if viewModel.isColorPresentOnAnySelectedVerses(color) {
                    Button(action: { viewModel.removeVerseColor(color) }) {
                        coloredCircle(with: color)
                            .overlay(
                                Image(systemName: "xmark")
                            )
                    }
                }
            }
            ForEach(highlightColors, id: \.self) { color in
                if !viewModel.isColorPresentOnAllSelectedVerses(color) {
                    Button(action: { viewModel.addVerseColor(color) }) {
                        coloredCircle(with: color)
                    }
                }
            }
        }
        .padding(.horizontal)
        .frame(height: buttonHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(surfaceTertiaryColor))
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
            .fill(surfaceTertiaryColor))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .font(ReaderFonts.fontLabelM)
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

    var swipeUpLabel: some View {
        HStack {
            Image(systemName: "chevron.up")
            Text(String.localized("verseActions.swipeUpLabel"))
        }
        .font(ReaderFonts.fontCaptionsL)
    }
}

#Preview {
    BibleReaderDrawer()
        .environment(BibleReaderViewModel.preview)
}
