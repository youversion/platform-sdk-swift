import Foundation
import SwiftUI
import YouVersionPlatformCore

/// An action in the reader's verse drawer. Use ``BibleReaderView/verseActions(_:)`` to
/// reorder or omit built-in actions and append host-specific buttons.
public struct BibleReaderVerseAction: Identifiable, Sendable {
    /// Opens the shared verse highlight palette.
    public static let highlight = Self(id: "highlight", kind: .highlight)
    /// Opens the built-in Notes create drawer.
    public static let save = Self(id: "save", kind: .save)
    /// Copies selected verses on supported platforms.
    public static let copy = Self(id: "copy", kind: .copy)
    /// Shares selected verses on supported platforms.
    public static let share = Self(id: "share", kind: .share)

    /// Stable identity, unique within the configured action list.
    public let id: String
    let kind: Kind
    let title: LocalizedStringResource?
    let image: Image?
    let action: (@MainActor @Sendable ([BibleReference]) -> Void)?

    enum Kind: Sendable {
        case highlight, save, copy, share, custom
    }

    /// Creates a custom button. Supply an ID unique within the action list.
    /// The callback receives a snapshot of the selected references, sorted and merged into
    /// contiguous ranges. The drawer closes and the selection clears before the callback runs.
    public init(
        id: String,
        title: LocalizedStringResource,
        systemImage: String,
        action: @escaping @MainActor @Sendable ([BibleReference]) -> Void
    ) {
        self.init(id: id, title: title, image: Image(systemName: systemImage), action: action)
    }

    /// Creates a custom button with a host-provided image, including asset images.
    /// Supply an ID unique within the action list. The callback receives sorted references
    /// merged into contiguous ranges, after the drawer closes and selection clears.
    public init(
        id: String,
        title: LocalizedStringResource,
        image: Image,
        action: @escaping @MainActor @Sendable ([BibleReference]) -> Void
    ) {
        self.id = id
        self.kind = .custom
        self.title = title
        self.image = image
        self.action = action
    }

    private init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
        self.title = nil
        self.image = nil
        self.action = nil
    }
}
