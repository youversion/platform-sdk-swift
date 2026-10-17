import SwiftUI
import YouVersionPlatformUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BibleReaderDrawer: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    private let buttonHeight = CGFloat(55)
    private let darkModeHighlightOpacity = 0.2

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
            Color(hex: "ffec5b"),
            Color(hex: "b4ffc1"),
            Color(hex: "bbf4ff"),
            Color(hex: "ffdca7"),
            Color(hex: "ffcff8"),
            Color(hex: "dfdcff")
        ]
    }

    /// Cross-platform color-name lookup. UIColor is UIKit-only, so guard
    /// per platform: iOS/tvOS/watchOS get UIColor, macOS gets NSColor.
    /// The output funnels into `.accessibilityIdentifier` — a
    /// UI-automation-only attribute that VoiceOver never speaks. Real
    /// assistive-tech users hear no highlight announcement on these
    /// buttons (matching the Bible iOS app's model — highlights are
    /// visual affordances, not narrated inline). Automation queries
    /// the identifier via Appium's `@name` fallback.
    private func accessibilityColorName(for color: Color) -> String {
        #if canImport(UIKit)
        return UIColor(color).accessibilityName
        #elseif canImport(AppKit)
        return NSColor(color).accessibilityName
        #else
        return ""
        #endif
    }

    private var highlightColorButtons: some View {
        let paletteHexes = Set(highlightColors.compactMap(\.hexString))
        let colorsToRemove = highlightColors.filter(viewModel.isColorPresentOnAnySelectedVerses)
            + viewModel.highlightColorsOnSelectedVerses.filter { color in
                guard let hex = color.hexString else {
                    return false
                }
                return !paletteHexes.contains(hex)
            }
        let colorsToAdd = highlightColors.filter { !viewModel.isColorPresentOnAllSelectedVerses($0) }
        return HStack {
            ForEach(colorsToRemove, id: \.self) { color in
                Button(action: { viewModel.removeVerseColor(color) }) {
                    coloredCircle(with: color)
                        .overlay(
                            Image("highlight_checkmark", bundle: .YouVersionUIBundle)
                                .renderingMode(.template)
                                .foregroundStyle(checkmarkColor(for: color))
                        )
                }
                .accessibilityIdentifier("Remove \(accessibilityColorName(for: color)) highlight")
            }
            ForEach(colorsToAdd, id: \.self) { color in
                Button(action: { viewModel.addVerseColor(color) }) {
                    coloredCircle(with: color)
                }
                .accessibilityIdentifier("\(accessibilityColorName(for: color)) highlight")
            }
        }
        .padding(.horizontal)
        .frame(height: buttonHeight)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(viewModel.readerSurfaceTertiaryColor))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
    }

    private var isDarkTheme: Bool {
        (viewModel.colorTheme?.colorScheme ?? .dark) == .dark
    }

    private func checkmarkColor(for color: Color) -> Color {
        isDarkTheme || color.isDarkHighlight ? .white : Color(hex: "#121212")
    }

    private func coloredCircle(with color: Color) -> some View {
        Circle()
            .fill(color.opacity(isDarkTheme ? darkModeHighlightOpacity : 1))
            .overlay(
                Circle().strokeBorder(isDarkTheme ? Color.white.opacity(0.2) : Color(hex: "#121212").opacity(0.2), lineWidth: 1)
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
