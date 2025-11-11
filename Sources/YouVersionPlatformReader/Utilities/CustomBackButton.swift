import SwiftUI
import YouVersionPlatformUI

extension View {
    func customBackButton(action: @escaping () -> Void) -> some View {
        modifier(CustomBackButtonModifier(action: action))
    }
}

private struct CustomBackButtonModifier: ViewModifier {
    let action: () -> Void

    private var shouldHideSystemBackButton: Bool {
        #if os(iOS)
        if #unavailable(iOS 26) {
            true
        } else {
            false
        }
        #else
        false
        #endif
    }

    func body(content: Content) -> some View {
        content
            .if(shouldHideSystemBackButton) { view in
                view.navigationBarBackButtonHidden(true)
            }
            .toolbar {
                #if os(iOS)
                if #unavailable(iOS 26) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            action()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel(String.localized("generic.back"))
                    }
                }
                #endif
            }
    }
}
