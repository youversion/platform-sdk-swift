import SwiftUI

public extension ColorScheme {
    /// The built-in ``ReaderTheme`` that naturally matches this color scheme:
    /// a light theme for ``ColorScheme/light``, a dark theme for ``ColorScheme/dark``.
    var readerTheme: ReaderTheme {
        switch self {
        case .dark: return ReaderTheme.theme(withId: 7)
        case .light: return ReaderTheme.theme(withId: 1)
        @unknown default: return ReaderTheme.theme()
        }
    }
}
