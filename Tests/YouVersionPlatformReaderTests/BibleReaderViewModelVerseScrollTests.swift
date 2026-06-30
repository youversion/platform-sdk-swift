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

        #expect(viewModel.scrollTarget == nil)
    }

    @Test
    func verseOneArmsNoScroll() {
        let viewModel = makeViewModel(verse: 1)

        #expect(viewModel.scrollTarget == nil)
    }

    @Test
    func restoredReferenceArmsNoScroll() {
        Support.clearReaderDefaults()
        defer { Support.clearReaderDefaults() }

        let viewModel = Support.makeViewModel(reference: nil, showsFullChapter: true)

        #expect(viewModel.scrollTarget == nil)
    }

    @Test
    func verseRangeModeArmsNoScroll() {
        let viewModel = makeViewModel(verse: 14, showsFullChapter: false)

        #expect(viewModel.scrollTarget == nil)
    }

    // A reader constructed fresh at a verse (the path loop-ios uses for VOTD and
    // bible stories) arms the scroll only when it opens in full-chapter mode.
    @Test
    func constructingFullChapterAtVerseArmsScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: true)

        #expect(viewModel.scrollTarget?.verseStart == 16)
    }

    @Test
    func constructingVerseRangeAtVerseArmsNoScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: false)

        #expect(viewModel.scrollTarget == nil)
    }

    @Test
    func goToReferenceFullChapterLoadsChapterAndArmsScroll() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: true)

        #expect(viewModel.reference.bookUSFM == "JHN")
        #expect(viewModel.reference.chapter == 3)
        #expect(viewModel.scrollTarget?.verseStart == 16)
    }

    @Test
    func goToReferenceVerseRangeArmsNoScroll() async {
        let viewModel = Support.makeViewModel()
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        let target = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        await viewModel.goToReference(target, showsFullChapter: false)

        #expect(viewModel.reference.chapter == 3)
        #expect(viewModel.scrollTarget == nil)
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
        #expect(viewModel.scrollTarget == nil)
    }
}

@MainActor
@Suite struct BibleReaderNavigationTests {
    @Test
    func requestSetsPendingReference() {
        let navigation = BibleReaderNavigation()
        let reference = BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16)

        navigation.request(reference, showsFullChapter: true)

        #expect(navigation.pendingReference?.reference == reference)
        #expect(navigation.pendingReference?.showsFullChapter == true)
    }

    @Test
    func requestDefaultsToVerseRange() {
        let navigation = BibleReaderNavigation()

        navigation.request(BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16))

        #expect(navigation.pendingReference?.showsFullChapter == false)
    }

    @Test
    func consumeClearsPendingReference() {
        let navigation = BibleReaderNavigation()
        navigation.request(BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16))

        navigation.consumePendingReference()

        #expect(navigation.pendingReference == nil)
    }
}
