import Testing
import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderViewSearchHiddenTests {
    private let reference = BibleReference(versionId: 111, bookId: "JHN", chapter: 1)

    @Test
    func showsSearchByDefault() {
        let reader = BibleReaderView(reference: reference)

        #expect(reader.isSearchHidden == false)
    }

    @Test
    func searchHiddenHidesSearch() {
        let reader = BibleReaderView(reference: reference).searchHidden()

        #expect(reader.isSearchHidden)
    }

    @Test
    func searchHiddenFalseShowsSearch() {
        let reader = BibleReaderView(reference: reference)
            .searchHidden()
            .searchHidden(false)

        #expect(reader.isSearchHidden == false)
    }
}
