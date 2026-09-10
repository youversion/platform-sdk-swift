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
            if distance >= 60 {
                isCompact = true
                distance = 0
            } else if distance <= -60 {
                isCompact = false
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
                    NavigationScrollGeometry(
                        offset: geometry.contentOffset.y + geometry.contentInsets.top,
                        maximumOffset: max(0, geometry.contentSize.height + geometry.contentInsets.top
                            + geometry.contentInsets.bottom - geometry.containerSize.height)
                    )
                } action: { oldValue, newValue in
                    state.update(
                        delta: newValue.offset - oldValue.offset,
                        isUserScrolling: isUserScrolling,
                        isAtBoundary: newValue.offset <= 2 || newValue.offset >= newValue.maximumOffset - 2
                    )
                    isCompact = state.isCompact
                }
        } else {
            content
        }
    }
}

private struct NavigationScrollGeometry: Equatable {
    let offset: CGFloat
    let maximumOffset: CGFloat
}
