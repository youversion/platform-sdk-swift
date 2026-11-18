import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    var highlightHexesOnSelectedVerses: [String] {
        Set(selectedVerses.flatMap { highlightsViewModel.highlights(for: $0) }.map { $0.color.lowercased() })
            .sorted()
    }

    /// Checks whether every selected verse has the requested RGB color.
    func isColorPresentOnAllSelectedVerses(hex: String) -> Bool {
        !selectedVerses.isEmpty && selectedVerses.allSatisfy { reference in
            highlightsViewModel.highlights(for: reference).contains { highlight in
                isSameHexColor(highlight.color, hex)
            }
        }
    }

    func isSameHexColor(_ a: String, _ b: String) -> Bool {
        guard let rgbA = Color.rgbValue(fromHex: a) else {
            return false
        }
        return rgbA == Color.rgbValue(fromHex: b)
    }

    func addVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "Reader")
            return
        }
        addHighlightOrStartPermissionFlow(references: selectedVerses, color: hex)
    }

    func removeVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "Reader")
            return
        }
        removeVerseColor(hex: hex)
    }

    /// Removes highlights from the selected verses whose RGB matches the given hex color, ignoring alpha.
    ///
    /// Clears the verse selection afterward.
    ///
    /// - Parameter hex: A color in `RGB`, `RRGGBB`, or `AARRGGBB` format, with or without a leading `#`.
    func removeVerseColor(hex: String) {
        for reference in selectedVerses {
            let highlights = highlightsViewModel.highlights(for: reference)
            for highlight in highlights where isSameHexColor(highlight.color, hex) {
                highlightsViewModel.removeHighlights(references: [reference])
            }
        }
        removeVerseSelection()
    }
}
