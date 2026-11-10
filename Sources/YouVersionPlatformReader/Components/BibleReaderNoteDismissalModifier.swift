import SwiftUI
#if canImport(UIKit) && !os(tvOS)
import UIKit
#endif

/// Observes attempts to dismiss a native sheet so unsaved text gets a discard confirmation.
struct BibleReaderNoteDismissalModifier: ViewModifier {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let draft: BibleReaderNoteDraft

    func body(content: Content) -> some View {
#if canImport(UIKit) && !os(tvOS)
        content.background {
            NotesSheetDismissalObserver(
                isDisabled: draft.hasTextChanges || draft.isSaving,
                onAttempt: { viewModel.requestDismissNote() },
                onDismiss: { viewModel.finishNote(draft) }
            )
        }
#else
        content.interactiveDismissDisabled(draft.hasTextChanges || draft.isSaving)
#endif
    }
}

#if canImport(UIKit) && !os(tvOS)
private struct NotesSheetDismissalObserver: UIViewControllerRepresentable {
    let isDisabled: Bool
    let onAttempt: () -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> DismissalController {
        DismissalController()
    }

    func updateUIViewController(_ controller: DismissalController, context: Context) {
        controller.isDisabled = isDisabled
        controller.onAttempt = onAttempt
        controller.onDismiss = onDismiss
        controller.installDelegate()
    }

    final class DismissalController: UIViewController, UIAdaptivePresentationControllerDelegate {
        var isDisabled = false
        var onAttempt: (() -> Void)?
        var onDismiss: (() -> Void)?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            installDelegate()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installDelegate()
        }

        func installDelegate() {
            var controller = parent
            while let current = controller {
                if let presentation = current.presentationController {
                    presentation.delegate = self
                    return
                }
                controller = current.parent
            }
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt?()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDismiss?()
        }
    }
}
#endif
