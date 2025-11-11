import SwiftUI
import YouVersionPlatformCore

struct BibleReaderFontSettingsView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            fontSizeButtons
            Button {
                viewModel.showingFontList = true
            } label: {
                fontDisplayButton
            }
            themePicker
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var fontDisplayButton: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(String.localized("fontSettings.label"))
                    .font(.caption)
                    .foregroundStyle(viewModel.readerTextMutedColor)
                let family = viewModel.textOptions.fontFamily
                Text(family)
                    .font(.custom(family, size: 22))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 18))
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderPrimaryColor, lineWidth: 1)
        )
    }

    private var themePicker: some View {
        ScrollView([.horizontal]) {
            HStack {
                ForEach(ReaderTheme.allThemes, id: \.id) { theme in
                    Button {
                        viewModel.colorTheme = theme
                    } label: {
                        colorPreview(
                            theme: theme,
                            selected: isSelected(theme)
                        )
                    }
                }
            }
            .padding(.bottom)
        }
    }

    private func isSelected(_ theme: ReaderTheme) -> Bool {
        if let currentColor = viewModel.colorTheme {
            return currentColor == theme
        }
        return false
    }

    private func colorPreview(theme: ReaderTheme, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().frame(width: 40, height: 2)
            Rectangle().frame(width: 32, height: 2)
            Rectangle().frame(width: 36, height: 2)
            Rectangle().frame(width: 25, height: 2)
            Spacer()
            HStack {
                Spacer()
                Image(systemName: selected ? "checkmark.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? viewModel.readerTextPrimaryColor : viewModel.readerTextMutedColor)
                Spacer()
            }
        }
        .padding(.top, 4)
        .padding()
        .foregroundStyle(theme.foreground)
        .frame(width: 56, height: 94)
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderSecondaryColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var fontSizeButtons: some View {
        HStack {
            let minWidth = CGFloat(126)
            let minHeight = CGFloat(48)

            HStack(spacing: 0) {
                Button {
                    viewModel.handleSmallerFontTap()
                } label: {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .frame(minWidth: minWidth, minHeight: minHeight)
                        .contentShape(HalfRoundedRectangleShape(side: .left))
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    HalfRoundedRectangleShape(side: .left)
                        .fill(buttonPrimaryColor)
                )

                Rectangle()
                    .frame(width: 2, height: 40)
                    .background(viewModel.readerCanvasPrimaryColor)
                    .overlay(viewModel.readerCanvasPrimaryColor)

                Button {
                    viewModel.handleBiggerFontTap()
                } label: {
                    Text("A")
                        .font(.system(size: 28))
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .frame(minWidth: minWidth, minHeight: minHeight)
                        .contentShape(HalfRoundedRectangleShape(side: .right))
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    HalfRoundedRectangleShape(side: .right)
                        .fill(buttonPrimaryColor)
                )
            }

            Spacer()

            Button {
                viewModel.selectNextLineSpacing()
            } label: {
                let currentSpacing = viewModel.textOptions.lineSpacing ?? CGFloat(ReaderFonts.lineSpacingOptions.first!)
                VStack(
                    alignment: .leading,
                    spacing: currentSpacing / 3
                ) {
                    Rectangle().frame(width: 32, height: 2)
                    Rectangle().frame(width: 32, height: 2)
                    Rectangle().frame(width: 32, height: 2)
                }
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .frame(minWidth: 57, minHeight: minHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonPrimaryColor)
                )
            }
            .buttonStyle(PlainButtonStyle())

        }
    }
}

#Preview {
    BibleReaderFontSettingsView()
        .environment(BibleReaderViewModel.preview)
}
