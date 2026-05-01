import SwiftUI

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    ///
    /// Avoid this modifier: when the condition flips, the concrete view type changes
    /// (`Self` vs `ModifiedContent<Self, …>`), forcing SwiftUI to tear down and rebuild
    /// the subtree and lose `@State`, focus, scroll position, and animation state. Apply
    /// the underlying modifier unconditionally with a conditional value instead — for
    /// example `.lineSpacing(value ?? 0)` or `.navigationBarBackButtonHidden(condition)`.
    @available(*, deprecated, message: "Causes view-identity churn when the condition flips. Apply the modifier unconditionally with a conditional value, e.g. .lineSpacing(value ?? 0).")
    @ViewBuilder public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
