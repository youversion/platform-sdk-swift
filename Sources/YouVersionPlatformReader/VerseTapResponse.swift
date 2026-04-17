import Foundation

/// Tells the SDK what to do after the host app's ``BibleReaderView/onVerseTap`` closure runs.
///
/// Return one of these cases from your `onVerseTap` closure to control
/// whether the reader updates its internal verse selection.
public enum VerseTapResponse: Sendable {
    /// The SDK toggles the tapped verse in or out of `selectedVerses`,
    /// causing the selection underline to appear or disappear.
    /// The built-in drawer and sign-in prompt are **not** shown.
    case toggleSelection

    /// The SDK takes no further action. The host app is fully responsible
    /// for any selection or UI changes.
    case handled
}
