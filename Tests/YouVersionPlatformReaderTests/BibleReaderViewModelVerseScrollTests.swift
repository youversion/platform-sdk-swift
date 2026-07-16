import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelVerseScrollTests {
    private typealias Support = BibleReaderViewModelTestSupport

    private func makeViewModel(verse: Int?, showsFullChapter: Bool = true) -> BibleReaderViewModel {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: verse)
        return Support.makeViewModel(reference: reference, showsFullChapter: showsFullChapter)
    }

    @Test
    func chapterOnlyReferenceArmsNoScroll() {
        let viewModel = makeViewModel(verse: nil)

        #expect(viewModel.scrollAction == .none)
    }

    @Test
    func verseOneArmsNoScroll() {
        let viewModel = makeViewModel(verse: 1)

        #expect(viewModel.scrollAction == .none)
    }

    @Test
    func restoredReferenceArmsNoScroll() {
        Support.clearReaderDefaults()
        defer { Support.clearReaderDefaults() }

        let viewModel = Support.makeViewModel(reference: nil, showsFullChapter: true)

        #expect(viewModel.scrollAction == .none)
    }

    @Test
    func verseRangeModeArmsNoScroll() {
        let viewModel = makeViewModel(verse: 14, showsFullChapter: false)

        #expect(viewModel.scrollAction == .none)
    }

    // A reader constructed fresh at a verse (the path loop-ios uses for VOTD and
    // bible stories) arms the scroll only when it opens in full-chapter mode.
    @Test
    func constructingFullChapterAtVerseArmsScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: true)

        #expect(viewModel.scrollAction == .reference(ScrollTarget(reference: reference, shouldFocus: false)))
    }

    @Test
    func constructingVerseRangeAtVerseArmsNoScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: false)

        #expect(viewModel.scrollAction == .none)
    }

    @Test
    func goToReferenceFullChapterLoadsChapterAndArmsScroll() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true)

        #expect(viewModel.reference.bookUSFM == "JHN")
        #expect(viewModel.reference.chapter == 3)
        #expect(viewModel.scrollAction == .reference(ScrollTarget(reference: target, shouldFocus: false)))
        #expect(viewModel.isChangingChapter)
    }

    @Test
    func goToReferenceVerseRangeArmsNoScroll() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: false)

        #expect(viewModel.reference.chapter == 3)
        #expect(viewModel.scrollAction == .top)
    }

    @Test
    func goToReferenceArmsNoScrollWhenVersionLoadFails() async {
        let repository = MockBibleVersionRepository()
        let viewModel = Support.makeViewModel(versionRepository: repository)
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        await repository.setThrownError(TestError())

        // A different version forces the cross-version load path, which throws.
        let target = BibleReference(versionId: Support.versionId + 1, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true)

        #expect(viewModel.reference.chapter != 3)
        #expect(viewModel.scrollAction == .none)
        #expect(viewModel.showsFullChapter == false)
        #expect(viewModel.isChangingChapter == false)
    }

    @Test
    func goToChapterReferenceArmsNoScroll() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        await viewModel.goToReference(
            BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3),
            showsFullChapter: true
        )

        #expect(viewModel.reference.chapter == 3)
        #expect(viewModel.scrollAction == .top)
    }

    // MARK: - Focus

    private func makeFocusedViewModel() -> BibleReaderViewModel {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        return viewModel
    }

    // A focused navigation arms the scroll to focus its target once it lands.
    // The dim itself isn't set until the coordinator scrolls the verse into view,
    // so it fades in on landing rather than during the scroll.
    @Test
    func goToReferenceFocusedArmsFocusScrollTarget() async {
        let viewModel = makeFocusedViewModel()

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true, shouldFocus: true)

        #expect(viewModel.scrollAction == .reference(ScrollTarget(reference: target, shouldFocus: true)))
        #expect(viewModel.focusedReference == nil)  // not focused until the scroll lands
    }

    // The coordinator calls focus once it has scrolled the verse into view.
    @Test
    func setFocusedFocusesTheVerse() async {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true, shouldFocus: true)

        viewModel.focusReference(target)

        #expect(viewModel.focusedReference == target)
    }

    @Test
    func goToReferenceWithoutFocusDoesNotArmFocus() async {
        let viewModel = makeFocusedViewModel()

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true)

        #expect(viewModel.scrollAction == .reference(ScrollTarget(reference: target, shouldFocus: false)))  // scroll only, no focus
        #expect(viewModel.focusedReference == nil)
    }

    // A chapter-only reference has no verse to scroll to, so nothing is armed and the
    // coordinator never reaches its focus step.
    @Test
    func focusingChapterOnlyReferenceArmsNothing() async {
        let viewModel = makeFocusedViewModel()

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3)
        await viewModel.goToReference(target, showsFullChapter: true, shouldFocus: true)

        #expect(viewModel.scrollAction == .top)
        #expect(viewModel.focusedReference == nil)
    }

    // Focusing in place dims the verse immediately, with no scroll armed — there's no
    // scroll to observe, so it sets focusedReference directly.
    @Test
    func focusFocusesWithoutScrolling() {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: 5)

        viewModel.focusReference(target)

        #expect(viewModel.focusedReference == target)
        #expect(viewModel.scrollAction == .none)  // nothing to scroll
    }

    @Test
    func focusIgnoresChapterOnlyReference() {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)

        viewModel.focusReference(target)

        #expect(viewModel.focusedReference == nil)
    }

    @Test
    func focusIgnoresReferenceInAnotherChapter() {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        viewModel.focusReference(target)

        #expect(viewModel.focusedReference == nil)
    }

    @Test
    func userScrollAwayClearsFocus() {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: 5)
        viewModel.lastScrollOffset = -400
        viewModel.focusReference(target)

        viewModel.handleScroll(offset: -600)

        #expect(viewModel.focusedReference == nil)
    }

    // The reveal scroll's settling stays within the threshold of its landing, so it
    // doesn't dismiss the focus.
    @Test
    func smallScrollKeepsFocus() {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: 5)
        viewModel.lastScrollOffset = -400   // the settled landing position
        viewModel.focusReference(target)

        viewModel.handleScroll(offset: -400.5)   // within the threshold

        #expect(viewModel.focusedReference == target)
    }

    @Test
    func verseTapClearsFocus() async {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true, shouldFocus: true)
        viewModel.focusReference(target)

        viewModel.handleVerseTap(reference: target, actionType: "", footnotes: [])

        #expect(viewModel.focusedReference == nil)
    }

    @Test
    func chapterNavigationClearsFocus() async {
        let viewModel = makeFocusedViewModel()
        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true, shouldFocus: true)
        viewModel.focusReference(target)

        viewModel.goToNextChapter()

        #expect(viewModel.focusedReference == nil)
    }
}

@MainActor
@Suite struct BibleReaderNavigationTests {
    @Test
    func requestSetsPendingRequest() {
        let navigation = BibleReaderNavigation()
        let reference = BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16)

        navigation.request(reference, showsFullChapter: true)

        #expect(navigation.pendingRequest?.reference == reference)
        #expect(navigation.pendingRequest?.showsFullChapter == true)
    }

    @Test
    func requestDefaultsToVerseRange() {
        let navigation = BibleReaderNavigation()

        navigation.request(BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16))

        #expect(navigation.pendingRequest?.showsFullChapter == false)
    }

    @Test
    func clearPendingRequestSetsItToNil() {
        let navigation = BibleReaderNavigation()
        navigation.request(BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16))

        navigation.clearPendingRequest()

        #expect(navigation.pendingRequest == nil)
    }

    @Test
    func focusRequestScrollsToVerseAndShowsFullChapter() {
        let navigation = BibleReaderNavigation()
        let reference = BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16)

        navigation.focusReference(reference)

        #expect(navigation.pendingRequest?.reference == reference)
        #expect(navigation.pendingRequest?.shouldFocus == true)
        #expect(navigation.pendingRequest?.scrollsToVerse == true)
        // Focus always shows the full chapter — there's nothing to dim around a
        // lone verse range.
        #expect(navigation.pendingRequest?.showsFullChapter == true)
    }

    @Test
    func focusInPlaceRequestFocusesWithoutScrolling() {
        let navigation = BibleReaderNavigation()
        let reference = BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16)

        navigation.focusReference(reference, scrollsToVerse: false)

        #expect(navigation.pendingRequest?.reference == reference)
        #expect(navigation.pendingRequest?.shouldFocus == true)
        #expect(navigation.pendingRequest?.scrollsToVerse == false)
    }

    @Test
    func requestIsNotFocused() {
        let navigation = BibleReaderNavigation()

        navigation.request(BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16))

        #expect(navigation.pendingRequest?.shouldFocus == false)
    }
}
