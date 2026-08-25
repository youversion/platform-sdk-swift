import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite struct BibleReaderViewModelBibleLoopTests {
    private static let versionId = 3034

    @Test
    func toggleBookPickerFromClosedExpandsCurrentBookAndOpens() {
        let vm = BibleReaderViewModel(
            reference: BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3)
        )
        vm.showingBookPicker = false
        vm.headerExpandedBookCode = nil

        vm.toggleBookPicker()

        #expect(vm.showingBookPicker == true)
        #expect(vm.headerExpandedBookCode == "JHN")
    }

    @Test
    func toggleBookPickerFromOpenClosesWithoutChangingExpandedBook() {
        let vm = BibleReaderViewModel(
            reference: BibleReference(versionId: Self.versionId, bookId: "JHN", chapter: 3)
        )
        vm.showingBookPicker = true
        vm.headerExpandedBookCode = "GEN"

        vm.toggleBookPicker()

        #expect(vm.showingBookPicker == false)
        #expect(vm.headerExpandedBookCode == "GEN")
    }
}
