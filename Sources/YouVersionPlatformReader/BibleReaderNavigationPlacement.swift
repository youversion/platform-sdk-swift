/// Preferred reader edge when horizontal host tab placement is absent or unavailable.
public struct BibleReaderNavigationPlacement: Equatable, Sendable {
    private enum Edge: Sendable {
        case top
        case bottom
    }

    private let edge: Edge

    /// Prefers reader navigation at the top when no horizontal host tab placement is detected.
    public static let topBar = BibleReaderNavigationPlacement(edge: .top)

    /// Prefers reader navigation at the bottom when no horizontal host tab placement is detected.
    public static let bottomBar = BibleReaderNavigationPlacement(edge: .bottom)
}
