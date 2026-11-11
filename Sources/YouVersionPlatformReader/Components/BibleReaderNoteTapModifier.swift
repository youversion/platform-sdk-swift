import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BibleReaderNoteTapModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 18, *) {
            content.gesture(NoteTapGesture(action: action))
        } else {
            content.onTapGesture(perform: action)
        }
#else
        content.onTapGesture(perform: action)
#endif
    }
}

#if os(iOS)
@available(iOS 18, *)
private struct NoteTapGesture: UIGestureRecognizerRepresentable {
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = TapRecognizer()
        recognizer.cancelsTouchesInView = false
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended {
            action()
        }
    }
}

// Standard taps also accept short swipes here. Cancel at the drag threshold without installing a competing pan recognizer.
private final class TapRecognizer: UITapGestureRecognizer {
    private var initialLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        initialLocation = touches.first?.location(in: nil)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if hasMoved(touches) {
            state = .failed
        } else {
            super.touchesMoved(touches, with: event)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if hasMoved(touches) {
            state = .failed
        } else {
            super.touchesEnded(touches, with: event)
        }
    }

    override func reset() {
        initialLocation = nil
        super.reset()
    }

    private func hasMoved(_ touches: Set<UITouch>) -> Bool {
        guard let initialLocation, let current = touches.first?.location(in: nil) else {
            return false
        }
        return hypot(current.x - initialLocation.x, current.y - initialLocation.y) >= 10
    }
}
#endif
