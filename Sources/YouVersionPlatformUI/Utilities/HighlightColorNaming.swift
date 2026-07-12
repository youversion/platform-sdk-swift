import SwiftUI

// Human-readable names for the fixed highlight color palette, keyed by the
// hex string used in `BibleReaderDrawer.highlightColors`. Used to populate
// `.accessibilityLabel` on the color picker buttons and `.accessibilityValue`
// on rendered verses so automation (and VoiceOver) can identify which color
// is displayed.
public enum HighlightColorNaming {

    public static func name(for hex: String) -> String {
        switch hex.lowercased() {
        case "fffe00": return "Yellow"
        case "5dff79": return "Green"
        case "00d6ff": return "Blue"
        case "ffc66f": return "Orange"
        case "ff95ef": return "Pink"
        default:       return "Custom"
        }
    }

    public static func name(for color: Color) -> String {
        return name(for: color.hexString ?? "")
    }
}
