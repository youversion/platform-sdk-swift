import AuthenticationServices
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel
#if !os(tvOS)
    @State private var contextProvider = ContextProvider()
#endif
    @State private var appName: String
    @State private var appSignInMessage: String

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    let fontSettingsDetent = PresentationDetent.height(360)
    let fontListDetent = PresentationDetent.height(480)
    @State private var selectedDetent: PresentationDetent
    @State private var detents: Set<PresentationDetent>

    public init(reference: BibleReference? = nil,
                appName: String,
                signInMessage: String
    ) {
        viewModel = BibleReaderViewModel(reference: reference)
        detents = [fontSettingsDetent, fontListDetent]
        selectedDetent = fontSettingsDetent
        self.appName = appName
        appSignInMessage = signInMessage
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
                .frame(height: 4)
            Divider()
                .frame(height: 1)
            ZStack {
                VStack {
                    mainScroller
                    Spacer(minLength: 0)
                }
                BibleReaderNavButtons()
                    .opacity(viewModel.showingVerseActionsDrawer ? 0 : 1)
                if viewModel.showingVerseActionsDrawer {
                    verseActionDrawer
                        .frame(maxWidth: viewModel.readerMaxWidth, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom))
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
        .sheet(isPresented: $viewModel.showingSignInSheet, content: {
            signInView
        })
        .sheet(isPresented: $viewModel.showingVersionsStack) {
            BibleReaderVersionsStack()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .onChange(of: viewModel.startSignInFlow) { _, newValue in
            if newValue {
                startSignIn()
            }
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
            withAnimation(.easeInOut) {
                selectedDetent = viewModel.showingFontList ? fontListDetent : fontSettingsDetent
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .presentationDragIndicator(.visible)
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationBackground(viewModel.readerCanvasPrimaryColor)
    }

    private var signInView: some View {
        BibleReaderSignInView(
            appName: appName,
            appMessage: appSignInMessage
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

    private var mainScroller: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scrollView")).minY)
                }
                .frame(height: 0)
                if viewModel.version != nil {
                    VStack(alignment: .leading) {
                        if viewModel.showBookIntro {
                            BibleReaderIntroView()
                        } else {
                            BibleTextView(
                                viewModel.reference,
                                textOptions: viewModel.textOptions,
                                selectedVerses: $viewModel.selectedVerses,
                                onVerseTap: { reference, actionType, footnotes, footnoteId in
                                    viewModel.handleVerseTap(reference: reference, actionType: actionType, footnotes: footnotes)
                                }
                            )
                        }
                        bibleCopyrightBlock
                    }
                    .frame(maxWidth: viewModel.readerMaxWidth)
                    .padding(.vertical)
                    .padding(.horizontal, 30)
                    .id("topOfContent")
                } else {
                    ProgressView()
                        .tint(viewModel.readerTextMutedColor)
                        .padding(.vertical, 48)
                }
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scrollView")).maxY)
                }
                .frame(height: 0)
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                Task { @MainActor in
                    viewModel.handleScroll(offset: value)
                }
            }
            .onChange(of: viewModel.scrollToTop) { _, shouldScroll in
                if shouldScroll {
                    scrollProxy.scrollTo("topOfContent", anchor: .top)
                    viewModel.scrollToTop = false
                    // Reset the changing chapter flag after a delay to allow scroll animation to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.isChangingChapter = false
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

    /// Helper to detect scroll offset in ScrollView
    struct ScrollOffsetPreferenceKey: PreferenceKey {
        typealias Value = CGFloat
        static var defaultValue: Value { .zero }
        static func reduce(value: inout Value, nextValue: () -> Value) {
            value = nextValue()
        }
    }

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
                
                viewModel.updateSignInState()
            } catch {
                print(error)
            }
        }
    }

}

#Preview {
    BibleReaderView(
        reference: BibleReference(versionId: 3034, bookUSFM: "PSA", chapter: 117),
        appName: "BibleReaderViewPreview",
        signInMessage: "This paragraph needs to explain why the user should sign in."
    )
    .environment(BibleReaderViewModel.preview)
}
