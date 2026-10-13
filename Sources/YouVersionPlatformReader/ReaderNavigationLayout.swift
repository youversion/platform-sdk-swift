import SwiftUI

/// The host tab bar's location, independent of OS availability.
enum ReaderTabLocation: Sendable {
    case none
    case top
    case bottom
    case other
}

/// A single policy for placement and presentation; never identifies a device model.
struct ReaderNavigationLayout: Equatable {
    let placement: BibleReaderNavigationPlacement
    let usesSystemToolbar: Bool
    let actions: [BibleReaderNavigationAction]

    init(options: BibleReaderNavigationOptions, tabLocation: ReaderTabLocation, hasVerticalToolbar: Bool) {
        switch tabLocation {
        case .top: placement = .bottomBar
        case .bottom: placement = .topBar
        case .none, .other: placement = options.placement
        }
        usesSystemToolbar = hasVerticalToolbar
        var seen: Set<BibleReaderNavigationAction> = []
        actions = options.actions.filter { seen.insert($0).inserted }
    }

    var primaryAction: BibleReaderNavigationAction? {
        placement == .bottomBar ? actions.first : nil
    }

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

/// Reads host container preferences outside the reader's own navigation stack.
struct ReaderNavigationEnvironmentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
            content.modifier(ReaderTabEnvironmentModifier())
        } else {
            content
        }
    }
}

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

/// TabView supplies placement to rendered descendants; a modifier on its content
/// can receive nil even while a background view receives the current placement.
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

#if compiler(>=6.4) && os(iOS)
@available(iOS 27.1, *)
private struct ReaderVerticalToolbarContextModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        content.environment(\.readerHasVerticalToolbar, verticalEdge != nil)
    }
}
#endif
