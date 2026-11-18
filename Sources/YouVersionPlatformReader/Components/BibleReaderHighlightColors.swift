import SwiftUI
import YouVersionPlatformUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared color chips for verse highlights and the note's optional color.
struct BibleReaderHighlightColors: View {
    static let palette = ["ffec5b", "b4ffc1", "bbf4ff", "ffdca7", "ffcff8", "dfdcff"]

    @Environment(BibleReaderViewModel.self) private var viewModel
    let selectedHexes: [String]
    let availableHexes: [String]
    var hasBackground = true
    let onRemove: (String) -> Void
    let onAdd: (String) -> Void

    var body: some View {
        let extraHexes = selectedHexes.filter { !Self.palette.contains($0) }
        HStack(spacing: 0) {
            ForEach(Self.palette + extraHexes, id: \.self) { hex in
                let isSelected = !availableHexes.contains(hex)
                HighlightChip(hex: hex, isSelected: isSelected) {
                    if isSelected {
                        onRemove(hex)
                    } else {
                        onAdd(hex)
                    }
                }
            }
        }
        .padding(.horizontal, hasBackground ? 12 : 0)
        .frame(minHeight: 55)
        .background(hasBackground ? viewModel.readerSurfaceTertiaryColor : .clear, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HighlightChip: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    private var color: Color { Color(hex: hex) }
    private var isDarkTheme: Bool { colorScheme == .dark }
    private var colorName: String {
#if canImport(UIKit)
        UIColor(color).accessibilityName
#elseif canImport(AppKit)
        NSColor(color).accessibilityName
#else
        hex
#endif
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(viewModel.readerCanvasPrimaryColor)
                .overlay {
                    Circle().fill(color.highlightFill(isDarkTheme: isDarkTheme))
                }
                .overlay(Circle().strokeBorder(isDarkTheme ? .white.opacity(0.2) : .black.opacity(0.2), lineWidth: 1))
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image("highlight_checkmark", bundle: .YouVersionUIBundle)
                            .renderingMode(.template)
                            .foregroundStyle(isDarkTheme || color.isDarkHighlight ? .white : Color(hex: "121212"))
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(isSelected ? "Remove \(colorName) highlight" : "\(colorName) highlight")
    }
}
