import SwiftUI

#if os(iOS)
/// Reads the system's corner-aware safe area without identifying the device.
@available(iOS 26.0, *)
struct ReaderWindowControlsClearance: UIViewRepresentable {
    @Binding var topInset: CGFloat

    func makeUIView(context: Context) -> ClearanceView {
        ClearanceView()
    }

    func updateUIView(_ uiView: ClearanceView, context: Context) {
        uiView.onInsetChange = { inset in
            Task { @MainActor in
                if topInset != inset {
                    topInset = inset
                }
            }
        }
        uiView.setNeedsLayout()
    }

    final class ClearanceView: UIView {
        var onInsetChange: ((CGFloat) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onInsetChange?(max(0, edgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top))
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            setNeedsLayout()
        }
    }
}
#endif
