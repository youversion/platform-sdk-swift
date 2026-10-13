/// Preferred reader edge when the host has no horizontal tab bar.
public enum BibleReaderNavigationPlacement: Sendable {
    case topBar
    case bottomBar
}

/// Optional reader actions, ordered from most to least important.
public enum BibleReaderNavigationAction: Hashable, Sendable {
    /// Audio is a placeholder until playback is implemented.
    case audio
    case search
}

/// Navigation preferences. A host's horizontal tab bar takes precedence over placement.
public struct BibleReaderNavigationOptions: Equatable, Sendable {
    public var placement: BibleReaderNavigationPlacement
    /// At the bottom, the first action appears beside the chapter picker and the second beside the upper menu.
    /// With custom top navigation, Search stays beside the menu; other actions appear inside it.
    /// Additional bottom actions appear in the menu. Duplicates are ignored.
    public var actions: [BibleReaderNavigationAction]

    public init(placement: BibleReaderNavigationPlacement = .bottomBar,
                actions: [BibleReaderNavigationAction] = [.audio, .search]) {
        self.placement = placement
        self.actions = actions
    }
}
