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

        #expect(viewModel.scrollTargetReference == nil)
    }

    @Test
    func verseOneArmsNoScroll() {
        let viewModel = makeViewModel(verse: 1)

        #expect(viewModel.scrollTargetReference == nil)
    }

    @Test
    func restoredReferenceArmsNoScroll() {
        Support.clearReaderDefaults()
        defer { Support.clearReaderDefaults() }

        let viewModel = Support.makeViewModel(reference: nil, showsFullChapter: true)

        #expect(viewModel.scrollTargetReference == nil)
    }

    @Test
    func verseRangeModeArmsNoScroll() {
        let viewModel = makeViewModel(verse: 14, showsFullChapter: false)

        #expect(viewModel.scrollTargetReference == nil)
    }

    // A reader constructed fresh at a verse (the path loop-ios uses for VOTD and
    // bible stories) arms the scroll only when it opens in full-chapter mode.
    @Test
    func constructingFullChapterAtVerseArmsScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: true)

        #expect(viewModel.scrollTargetReference?.verseStart == 16)
    }

    @Test
    func constructingVerseRangeAtVerseArmsNoScroll() {
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        let viewModel = Support.makeViewModel(reference: reference, showsFullChapter: false)

        #expect(viewModel.scrollTargetReference == nil)
    }
}
