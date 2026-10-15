import SwiftUI

/// The host tab bar's location, independent of OS availability.
/// `none` also represents unavailable detection (for example, on iOS 17);
/// it is not proof that the host has no tabs. `other` includes sidebar placement.
enum ReaderTabLocation: Sendable {
    case none
    case top
    case bottom
    case other
}

/// Implemented reader-owned actions.
enum BibleReaderNavigationAction: Equatable, Sendable {
    case search
}

/// A single policy for placement and presentation; never identifies a device model.
/// Keeping this separate from the views lets both custom controls and native items
/// follow the same tab-placement rules as an iPad window is resized.
struct ReaderNavigationLayout: Equatable {
    let placement: BibleReaderNavigationPlacement
    let usesSystemToolbar: Bool
    let navigationStackUsage: BibleReaderNavigationStackUsage
    let actions: [BibleReaderNavigationAction] = [.search]

    /// Horizontal tabs take precedence so reader navigation stays on the opposite edge.
    /// Without a detected horizontal tab bar, use the host's preference. This also lets
    /// iOS 17 hosts request top controls explicitly when their tabs are at the bottom.
    /// Native items require both host consent (the host supplies the navigation container)
    /// and a system vertical toolbar. Width alone must not change navigation ownership.
    init(preferredPlacement: BibleReaderNavigationPlacement = .bottomBar,
         navigationStackUsage: BibleReaderNavigationStackUsage = .none,
         tabLocation: ReaderTabLocation,
         hasVerticalToolbar: Bool) {
        switch tabLocation {
        case .top: placement = .bottomBar
        case .bottom: placement = .topBar
        case .none, .other: placement = preferredPlacement
        }
        self.navigationStackUsage = navigationStackUsage
        usesSystemToolbar = navigationStackUsage != .none && hasVerticalToolbar
    }

    var primaryAction: BibleReaderNavigationAction? {
        placement == .bottomBar ? actions.first : nil
    }

    /// Bottom navigation reserves its first action for the picker row. Custom top
    /// navigation keeps Search beside the menu; native top navigation puts it in the
    /// menu so the system can arrange the remaining toolbar controls on the vertical edge.
    var upperAction: BibleReaderNavigationAction? {
        if placement == .bottomBar {
            return actions.dropFirst().first
        }
        return !usesSystemToolbar && actions.contains(.search) ? .search : nil
    }

    var menuActions: [BibleReaderNavigationAction] {
        placement == .topBar ? actions.filter { $0 != upperAction } : Array(actions.dropFirst(2))
    }

}

extension EnvironmentValues {
    @Entry var readerTabLocation = ReaderTabLocation.none
    @Entry var readerHasVerticalToolbar = false
}

/// Reads host container preferences without creating a navigation stack.
/// Older systems cannot report tab placement through this API, so they retain the
/// default environment values and use the host's explicit placement preference.
struct ReaderNavigationEnvironmentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
            content.modifier(ReaderTabEnvironmentModifier())
        } else {
            content
        }
    }
}

/// Relays the rendered observer's result to reader content. Keeping the observer
/// outside that environment write lets it read the host's placement, while the
/// reader consumes a value that is also available on older deployment targets.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
private struct ReaderTabEnvironmentModifier: ViewModifier {
    @State private var location = ReaderTabLocation.none

    func body(content: Content) -> some View {
        content
            .environment(\.readerTabLocation, location)
            .background {
                ReaderTabPlacementObserver(location: $location)
            }
            .modifier(ReaderVerticalToolbarEnvironmentModifier())
    }
}

/// During simulator testing, reading placement directly in the content modifier
/// returned nil while this rendered background received the host's actual placement.
/// Observe both the initial value and later changes: resizing an iPad window can move
/// tabs between top and bottom without recreating the reader. Safe-area size alone
/// did not distinguish those placements reliably in the earlier layout experiments.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
private struct ReaderTabPlacementObserver: View {
    @Environment(\.tabBarPlacement) private var placement
    @Binding var location: ReaderTabLocation

    var body: some View {
        Color.clear
            .onChange(of: placement, initial: true) { _, placement in
                location = switch placement {
                case .topBar: .top
                case .bottomBar: .bottom
                case nil: .none
                default: .other
                }
            }
    }
}

/// The compiler gate keeps the new iOS-only symbol out of builds with older
/// toolchains; the availability check protects execution on older OS versions.
/// Unsupported combinations keep custom controls, even when the host opts in.
private struct ReaderVerticalToolbarEnvironmentModifier: ViewModifier {
    func body(content: Content) -> some View {
#if compiler(>=6.4) && os(iOS)
        if #available(iOS 27.1, *) {
            content.modifier(ReaderVerticalToolbarContextModifier())
        } else {
            content
        }
#else
        content
#endif
    }
}

// The declaration needs the same compile-time gate as its use above.
#if compiler(>=6.4) && os(iOS)
@available(iOS 27.1, *)
private struct ReaderVerticalToolbarContextModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        content.environment(\.readerHasVerticalToolbar, verticalEdge != nil)
    }
}
#endif
