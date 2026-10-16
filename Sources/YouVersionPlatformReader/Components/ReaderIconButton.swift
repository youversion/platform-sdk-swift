import SwiftUI

extension View {
    // Keep SwiftUI's method syntax for a chainable view modifier.
    /// Caps icon scaling while preserving a 44-point rectangular hit target.
    func readerIconButton() -> some View { // swiftlint:disable:this var_over_func
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
