import SwiftUI

/// Tracks deliberate scrolling independently of programmatic verse navigation.
struct ReaderNavigationScrollState {
    private(set) var isCompact = false
    private var distance: CGFloat = 0

    mutating func update(delta: CGFloat, isUserScrolling: Bool, isAtBoundary: Bool) {
        if isAtBoundary {
            isCompact = false
            distance = 0
        } else if isUserScrolling {
            if (distance > 0 && delta < 0) || (distance < 0 && delta > 0) {
                distance = 0
            }
            distance += delta
            if abs(distance) >= 60 {
                isCompact = true
                distance = 0
            }
        }
    }

    mutating func endGesture() {
        distance = 0
    }
}

struct ReaderNavigationScrollModifier: ViewModifier {
    @Binding var isCompact: Bool
    @State private var state = ReaderNavigationScrollState()
    @State private var isUserScrolling = false

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
            content
                .onChange(of: isCompact) { _, value in
                    if !value {
                        state = ReaderNavigationScrollState()
                    }
                }
                .onScrollPhaseChange { _, phase in
                    isUserScrolling = phase == .interacting || phase == .decelerating
                    if !isUserScrolling {
                        state.endGesture()
                    }
                }
                .onScrollGeometryChange(for: NavigationScrollGeometry.self) { geometry in
                    NavigationScrollGeometry(geometry)
                } action: { oldValue, newValue in
                    state.update(
                        delta: newValue.offset - oldValue.offset,
                        isUserScrolling: isUserScrolling,
                        isAtBoundary: newValue.isAtBoundary
                    )
                    isCompact = state.isCompact
                }
        } else {
            content
        }
    }
}

struct NavigationScrollGeometry: Equatable {
    let offset: CGFloat
    private let maximumOffset: CGFloat

    @available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
    init(_ geometry: ScrollGeometry) {
        offset = geometry.contentOffset.y + geometry.contentInsets.top
        maximumOffset = max(0, geometry.contentSize.height - geometry.containerSize.height)
    }

    var isAtBoundary: Bool {
        offset <= 2 || offset >= maximumOffset - 2
    }
}
