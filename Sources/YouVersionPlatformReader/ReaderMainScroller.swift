import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct ReaderMainScroller<Footer: View>: View {
    @Bindable var viewModel: BibleReaderViewModel
    let verseScrollCoordinator: VerseScrollCoordinator
    let audioActiveReference: BibleReference?
    let bibleCopyrightBlock: Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var verseAnchors: [Int] = []
    @State private var lastScrolledVerse: Int?

    init(
        viewModel: BibleReaderViewModel,
        verseScrollCoordinator: VerseScrollCoordinator,
        audioActiveReference: BibleReference?,
        @ViewBuilder bibleCopyrightBlock: () -> Footer
    ) {
        self.viewModel = viewModel
        self.verseScrollCoordinator = verseScrollCoordinator
        self.audioActiveReference = audioActiveReference
        self.bibleCopyrightBlock = bibleCopyrightBlock()
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                if viewModel.version != nil {
                    chapterContent
                        .frame(maxWidth: viewModel.readerMaxWidth)
                        .padding(.vertical)
                        .padding(.horizontal, 30)
                        .id("topOfContent")
                        // Hide the content until the verse scroll lands
                        // to avoid flashing.
                        .opacity(verseScrollCoordinator.isScrollPending ? 0 : 1)
                        .overlay(alignment: .top) {
                            if verseScrollCoordinator.isScrollPending {
                                progressView
                            }
                        }
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named("scrollView"))
                        } action: { newFrame in
                            viewModel.handleScroll(offset: newFrame.minY, contentHeight: newFrame.height)
                        }
                } else {
                    progressView
                }
            }
            .coordinateSpace(.named("scrollView"))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewModel.scrollViewHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newHeight in
                            viewModel.scrollViewHeight = newHeight
                        }
                }
            )
            .onPreferenceChange(VerseAnchorsPreferenceKey.self) { verseAnchors = $0 }
            .onChange(of: viewModel.scrollToTop) { _, shouldScroll in
                if shouldScroll {
                    scrollProxy.scrollTo("topOfContent", anchor: .top)
                    viewModel.scrollToTop = false
                    lastScrolledVerse = nil
                    // Wait for scroll animation before clearing the flag.
                    Task { @MainActor in
                        // swiftlint:disable:next common_debug_statements
                        try? await Task.sleep(for: .seconds(0.5))
                        viewModel.isChangingChapter = false
                    }
                }
            }
            .onChange(of: viewModel.reference) {
                verseAnchors = []
                lastScrolledVerse = nil
            }
            .onChange(of: audioActiveReference) { _, _ in
                applyAudioScrollIfNeeded(scrollProxy: scrollProxy)
            }
            .onChange(of: verseAnchors) { _, _ in
                applyAudioScrollIfNeeded(scrollProxy: scrollProxy)
            }
            .onPreferenceChange(ChapterScrollAnchorsKey.self) { anchors in
                verseScrollCoordinator.handleAnchors(anchors, proxy: scrollProxy)
            }
            .onChange(of: viewModel.scrollTargetReference, initial: true) { _, target in
                if target != nil {
                    verseScrollCoordinator.handleScrollTarget(proxy: scrollProxy)
                }
            }
        }
    }

    private var chapterContent: some View {
        VStack(alignment: .leading) {
            if viewModel.showBookIntro {
                BibleReaderIntroView()
            } else {
                BibleTextView(
                    viewModel.showsFullChapter ? viewModel.reference.chapterReference : viewModel.reference,
                    textOptions: viewModel.textOptions,
                    selectedVerses: $viewModel.selectedVerses,
                    onVerseTap: { reference, actionType, footnotes, footnoteId in
                        viewModel.handleVerseTap(reference: reference, actionType: actionType, footnotes: footnotes)
                    },
                    onCollectibleTap: { id in
                        viewModel.onCollectibleTap?(id)
                    },
                    onAnchorsChanged: { anchors in
                        verseAnchors = anchors
                    },
                    audioActiveVerse: audioActiveReference?.verseStart
                )
            }
            VStack(alignment: .center) {
                bibleCopyrightBlock
                    .frame(maxWidth: viewModel.readerMaxWidth)
            }
        }
    }

    private var progressView: some View {
        ProgressView()
            .tint(viewModel.readerTextMutedColor)
            .padding(.vertical, 48)
    }

    private func applyAudioScrollIfNeeded(scrollProxy: ScrollViewProxy) {
        guard let audioRef = audioActiveReference,
              let verse = audioRef.verseStart,
              audioRef.chapter == viewModel.reference.chapter,
              audioRef.bookUSFM.uppercased() == viewModel.reference.bookUSFM.uppercased(),
              !viewModel.isChangingChapter else {
            return
        }
        guard let anchorVerse = verseAnchors.last(where: { $0 <= verse }) else {
            return
        }
        guard anchorVerse != lastScrolledVerse else {
            return
        }
        lastScrolledVerse = anchorVerse
        let anchorId = "ch\(viewModel.reference.chapter)v\(anchorVerse)"
        Task { @MainActor in
            let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.3)
            withAnimation(animation) {
                scrollProxy.scrollTo(anchorId, anchor: .center)
            }
        }
    }
}
