/// How the reader may use a navigation stack supplied by the host app.
/// These options do not create a navigation stack.
public struct BibleReaderNavigationStackUsage: Equatable, Sendable {
    private enum Usage: Sendable {
        case none
        case shared
        case justForReader
    }

    private let usage: Usage

    /// Uses custom controls without contributing toolbar items or changing the host's bar.
    /// A navigation stack is not required. An existing host bar remains under host control.
    public static let none = BibleReaderNavigationStackUsage(usage: .none)

    /// Adds reader actions to the host toolbar, with chapter arrows on vertical toolbars.
    /// Requires a host-provided stack and preserves its bar visibility and minimization.
    /// The host is responsible for keeping the bar visible to expose native reader actions.
    public static let shared = BibleReaderNavigationStackUsage(usage: .shared)

    /// Uses a host-provided stack dedicated to the reader.
    /// Hides its horizontal navigation bar, including any host title or Back button.
    /// Shows its vertical toolbar and disables minimization to keep reader actions available.
    public static let justForReader = BibleReaderNavigationStackUsage(usage: .justForReader)
}
