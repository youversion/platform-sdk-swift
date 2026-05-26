import AuthenticationServices
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel?

    private let initialReference: BibleReference?
    private let verseSelectionStyle: VerseSelectionStyle
    private let onVerseTap: ((BibleReference) -> VerseTapResponse)?
    private let onNoteIndicatorTap: ((BibleReference) -> Void)?
    private let onReferenceChange: ((BibleReference) -> Void)?
    private let onChapterComplete: ((BibleReference) -> Void)?
    private let audioActiveIndicatorColor: Color?
    private let externalSelectedVerses: Binding<Set<BibleReference>>?
    private let audioActiveReference: BibleReference?

    /// Creates a Bible reader view.
    ///
    /// - Parameters:
    ///   - reference: The Bible reference to display initially. When `nil`, the reader
    ///     restores the last-viewed reference or defaults to John 1.
    ///   - selectedVerses: An optional binding to the set of selected verses. When
    ///     provided, the client can read which verses are selected and clear the
    ///     selection programmatically (e.g. on sheet dismiss). The SDK updates this
    ///     binding whenever the internal selection changes.
    ///   - verseSelectionStyle: Controls the visual style of the underline drawn
    ///     beneath selected verses. Defaults to ``VerseSelectionStyle/solid``.
    ///   - onVerseTap: An optional closure called when the user taps a verse.
    ///     The closure receives the tapped ``BibleReference`` and returns a
    ///     ``VerseTapResponse`` telling the SDK what to do next. Return
    ///     ``VerseTapResponse/toggleSelection`` to have the SDK toggle the verse
    ///     in `selectedVerses` (the underline appears), or ``VerseTapResponse/handled``
    ///     if the host app handled everything and the SDK should take no action.
    ///     When `nil` (the default), tapping a verse triggers the built-in sign-in
    ///     prompt for unauthenticated users (unless sign-in is disabled via
    ///     ``YouVersionPlatformConfiguration/isSignInEnabled``) or opens the verse
    ///     actions drawer for authenticated users. Footnote taps are always handled
    ///     by the reader regardless of this closure.
    ///   - onNoteIndicatorTap: An optional closure called when the user taps a verse
    ///     that has a note indicator (pencil icon) and is not already selected. When
    ///     provided, the SDK calls this instead of `onVerseTap` for those taps.
    ///   - onReferenceChange: An optional closure called whenever the displayed
    ///     chapter reference changes — for example when the user taps the
    ///     next/previous chapter buttons or picks a new book/chapter from the header.
    ///   - onChapterComplete: An optional closure called once when the bottom of
    ///     the chapter content scrolls into the viewport — i.e. the reader has
    ///     reached the end of the chapter. For chapters shorter than the
    ///     viewport, this fires as soon as the chapter is displayed. Fires at
    ///     most once per chapter; resets when the reader navigates to a
    ///     different chapter.
    ///   - audioActiveReference: The verse currently being narrated by audio
    ///     playback. When this value changes, the reader auto-scrolls to keep
    ///     the active verse visible. Pass `nil` when audio is not playing.
    ///   - audioActiveIndicatorColor: The color of the vertical bar drawn next
    ///     to the verse being narrated. Pass `nil` to hide the indicator.
    public init(reference: BibleReference? = nil,
                selectedVerses: Binding<Set<BibleReference>>? = nil,
                verseSelectionStyle: VerseSelectionStyle = .solid,
                onVerseTap: ((BibleReference) -> VerseTapResponse)? = nil,
                onNoteIndicatorTap: ((BibleReference) -> Void)? = nil,
                onReferenceChange: ((BibleReference) -> Void)? = nil,
                onChapterComplete: ((BibleReference) -> Void)? = nil,
                audioActiveReference: BibleReference? = nil,
                audioActiveIndicatorColor: Color? = nil
    ) {
        assert(
            onVerseTap != nil || YouVersionPlatformConfiguration.isSignInEnabled,
            "onVerseTap must be provided OR YouVersion sign-in must be enabled"
        )
        self.initialReference = reference
        self.externalSelectedVerses = selectedVerses
        self.verseSelectionStyle = verseSelectionStyle
        self.onVerseTap = onVerseTap
        self.onNoteIndicatorTap = onNoteIndicatorTap
        self.onReferenceChange = onReferenceChange
        self.onChapterComplete = onChapterComplete
        self.audioActiveReference = audioActiveReference
        self.audioActiveIndicatorColor = audioActiveIndicatorColor
    }

    /// Creates a Bible reader view with sign-in configuration.
    ///
    /// - Parameters:
    ///   - reference: The Bible reference to display initially.
    ///   - appName: The name of the host app, shown in sign-in dialogs.
    ///   - signInMessage: A message displayed on the sign-in sheet.
    ///   - onVerseTap: An optional closure called when the user taps a verse.
    @available(*, deprecated, message: "Set appName and signInPromptMessage on YouVersionPlatformConfiguration instead.")
    public init(reference: BibleReference? = nil,
                appName: String,
                signInMessage: String,
                selectedVerses: Binding<Set<BibleReference>>? = nil,
                verseSelectionStyle: VerseSelectionStyle = .solid,
                onVerseTap: ((BibleReference) -> VerseTapResponse)? = nil
    ) {
        YouVersionPlatformConfiguration.configureSignIn(appName: appName, signInPromptMessage: signInMessage)
        self.init(reference: reference, selectedVerses: selectedVerses, verseSelectionStyle: verseSelectionStyle, onVerseTap: onVerseTap)
    }

    public var body: some View {
        Group {
            if let viewModel {
                ReaderContent(
                    viewModel: viewModel,
                    externalSelectedVerses: externalSelectedVerses,
                    audioActiveReference: audioActiveReference
                )
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                viewModel = BibleReaderViewModel(
                    reference: initialReference,
                    verseSelectionStyle: verseSelectionStyle,
                    audioActiveIndicatorColor: audioActiveIndicatorColor,
                    onVerseTap: onVerseTap,
                    onNoteIndicatorTap: onNoteIndicatorTap,
                    onReferenceChange: onReferenceChange,
                    onChapterComplete: onChapterComplete
                )
            }
        }
    }
}

private struct ReaderContent: View {
    @Bindable var viewModel: BibleReaderViewModel
    let externalSelectedVerses: Binding<Set<BibleReference>>?
    let audioActiveReference: BibleReference?

#if !os(tvOS)
    @State private var contextProvider = ContextProvider()
#endif

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fontSettingsDetent = PresentationDetent.height(360)
    private let fontListDetent = PresentationDetent.height(480)
    @State private var selectedDetent = PresentationDetent.height(360)
    @State private var detents: Set<PresentationDetent> = [.height(360), .height(480)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
                .frame(height: 4)
            Divider()
                .frame(height: 1)
            ZStack {
                VStack {
                    ReaderMainScroller(
                        viewModel: viewModel,
                        audioActiveReference: audioActiveReference
                    ) {
                        bibleCopyrightBlock
                    }
                    Spacer(minLength: 0)
                }
                BibleReaderNavButtons()
                    .opacity(viewModel.showingVerseActionsDrawer ? 0 : 1)
                if viewModel.showingVerseActionsDrawer {
                    verseActionDrawer
                        .frame(maxWidth: viewModel.readerMaxWidth, maxHeight: .infinity, alignment: .bottom)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                }
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
        .alert(
            viewModel.textForGenericAlertTitle,
            isPresented: $viewModel.showGenericAlert
        ) {
            Button(viewModel.textForGenericAlertOKButton) { }
        } message: {
            Text(viewModel.textForGenericAlertBody)
        }
        .alert(
            String.localized("signOut.question"),
            isPresented: $viewModel.showSignOutConfirmation
        ) {
            Button(String.localized("button.signOut"), role: .destructive) { viewModel.confirmSignOut() }
            Button(String.localized("generic.cancel"), role: .cancel) { }
        } message: {
            Text(String.localized("signOut.explanation"))
        }
        .sheet(isPresented: $viewModel.showingFontSettings, content: {
            fontSettingsSheet
        })
        .sheet(isPresented: $viewModel.showingFootnotes, content: {
            BibleReaderFootnotesView()
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .presentationBackground(viewModel.readerCanvasPrimaryColor)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        })
        .sheet(isPresented: $viewModel.showingIntroFootnoteSheet, content: {
            BibleReaderIntroFootnoteView()
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .presentationBackground(viewModel.readerCanvasPrimaryColor)
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(250), .medium, .large])
        })
        .sheet(isPresented: $viewModel.showingSignInSheet) {
            signInView
        }
        .sheet(isPresented: $viewModel.showingVersionsStack) {
            BibleVersionsStack()
                .environment(viewModel.versionsViewModel)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .onChange(of: viewModel.startSignInFlow) { _, newValue in
            if newValue {
                startSignIn()
            }
        }
        .onChange(of: viewModel.selectedVerses) { _, newValue in
            externalSelectedVerses?.wrappedValue = newValue
        }
        .onChange(of: externalSelectedVerses?.wrappedValue) { _, newValue in
            if let newValue, newValue != viewModel.selectedVerses {
                viewModel.selectedVerses = newValue
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, newValue in
            viewModel.isReduceMotionEnabled = newValue
        }
        .onAppear {
            viewModel.resetChapterCompleteTracking()
        }
        .onChange(of: viewModel.reference) { _, newReference in
            viewModel.resetChapterCompleteTracking()
            viewModel.onReferenceChange?(newReference)
        }
        .environment(viewModel)
        .environment(\.colorScheme, viewModel.colorTheme?.colorScheme ?? .dark)
    }

    // MARK: - Helper views
    private var header: some View {
        HStack {
            if viewModel.version != nil {
                BibleReaderHeaderView(
                    showChrome: true,
                    onSelectionChange: { version, book, chapter, passageId in
                        Task {
                            let reference = BibleReference(versionId: version, bookUSFM: book, chapter: chapter ?? 1)
                            await viewModel.onHeaderSelectionChange(reference, showIntro: chapter == nil)
                        }
                    },
                    onCompactTap: {
                        viewModel.showChrome = true
                    }
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
    }

    private var fontSettingsSheet: some View {
        Group {
            if viewModel.showingFontList {
                BibleReaderFontListView()
            } else {
                BibleReaderFontSettingsView()
            }
        }
        .onChange(of: viewModel.showingFontList) {
            withAnimation(reduceMotion ? nil : .easeInOut) {
                selectedDetent = viewModel.showingFontList ? fontListDetent : fontSettingsDetent
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .presentationDragIndicator(.visible)
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationBackground(viewModel.readerCanvasPrimaryColor)
    }

    private var signInView: some View {
        SignInWithYouVersionView(
            textPrimaryColor: viewModel.readerTextPrimaryColor,
            borderPrimaryColor: viewModel.readerBorderPrimaryColor,
            buttonPrimaryColor: viewModel.readerButtonPrimaryColor,
            borderSecondaryColor: viewModel.readerBorderSecondaryColor,
            buttonSecondaryColor: viewModel.readerButtonSecondaryColor,
            onSignIn: {
                viewModel.signIn()
                viewModel.showingSignInSheet = false
            },
            onDismiss: {
                viewModel.showingSignInSheet = false
            }
        )
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .presentationDetents([.fraction(0.80)])
        .presentationDragIndicator(.visible)
        .presentationBackground(viewModel.readerCanvasPrimaryColor)
    }

    private var verseActionDrawer: some View {
        BibleReaderDrawer()
            .presentationDetents([PresentationDetent.height(160)])
            .presentationDragIndicator(.visible)
            .presentationBackground(viewModel.readerCanvasPrimaryColor)
    }

    private var bibleCopyrightBlock: some View {
        VStack(alignment: .center) {
            if let version = viewModel.version {
                Text(version.copyright ?? version.promotionalContent ?? "")
                    .multilineTextAlignment(.center)
                    .font(.caption2)
                    .foregroundStyle(viewModel.readerTextMutedColor)
                    .padding(4)
                    .padding(.horizontal, 36)
                if let urlText = version.readerFooterUrl,
                   let url = URL(string: urlText) {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(viewModel.readerTextPrimaryColor)
                        Text(String.localized("reader.learnMore"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(viewModel.readerTextPrimaryColor)
                    }
                }
            }
        }
    }

#if !os(tvOS)
    class ContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first
            else {
                return ASPresentationAnchor()
            }
            return window
#else
            return ASPresentationAnchor()
#endif
        }
    }
#endif

    // MARK: - Action handlers

    private func startSignIn() {
        Task {
            do {
                viewModel.startSignInFlow = false
#if !os(tvOS)
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: [.profile, .email],
                    contextProvider: contextProvider
                )
                dump(result)
#endif

                await viewModel.updateSignInState()
            } catch {
                YouVersionPlatformLogger.error("Sign-in error: \(error)", category: "BibleReader")
            }
        }
    }
}

#Preview {
    BibleReaderView(
        reference: BibleReference(versionId: 3034, bookUSFM: "PSA", chapter: 117)
    )
    .environment(BibleReaderViewModel.preview)
}
