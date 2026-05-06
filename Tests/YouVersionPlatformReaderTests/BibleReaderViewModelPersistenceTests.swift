import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

@MainActor
@Suite(.serialized) struct BibleReaderViewModelPersistenceTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func initWithExplicitReferenceUsesReferenceAndHidesIntro() {
        Support.clearReaderDefaults()
        UserDefaults.standard.set(true, forKey: Support.displayIntroKey)
        let savedReference = BibleReference(versionId: 111, bookUSFM: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Support.referenceKey)

        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)
        )

        #expect(viewModel.reference == BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func initWithoutExplicitReferenceRestoresSavedReferenceAndIntroState() {
        Support.clearReaderDefaults()
        let savedReference = BibleReference(versionId: 111, bookUSFM: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Support.referenceKey)
        UserDefaults.standard.set(true, forKey: Support.displayIntroKey)

        let viewModel = Support.makeViewModel(reference: nil)

        #expect(viewModel.reference == savedReference)
        #expect(viewModel.showBookIntro)
    }

    @Test
    func initWithoutSavedReferenceUsesDefaultJohnOneReference() {
        Support.clearReaderDefaults()

        let viewModel = Support.makeViewModel(reference: nil)

        #expect(viewModel.reference == BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func referenceAndShowBookIntroPersistWhenChanged() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookUSFM: "GEN", chapter: 1)
        )

        let newReference = BibleReference(versionId: Support.versionId, bookUSFM: "ROM", chapter: 8)
        viewModel.reference = newReference
        viewModel.showBookIntro = true

        let storedData = UserDefaults.standard.data(forKey: Support.referenceKey)
        let storedReference = storedData.flatMap { try? JSONDecoder().decode(BibleReference.self, from: $0) }
        #expect(storedReference == newReference)
        #expect(UserDefaults.standard.bool(forKey: Support.displayIntroKey))
    }

    @Test
    func fontControlsClampToAvailableSizesAndPersistSettings() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()

        #expect(viewModel.textOptions.fontSize == 21)

        viewModel.decreaseFontSize()
        #expect(viewModel.textOptions.fontSize == 18)

        viewModel.increaseFontSize()
        #expect(viewModel.textOptions.fontSize == 21)

        viewModel.setFont(family: "Georgia", size: 27)
        viewModel.increaseFontSize()
        #expect(viewModel.textOptions.fontFamily == "Georgia")
        #expect(viewModel.textOptions.fontSize == 27)

        let restoredViewModel = Support.makeViewModel()
        #expect(restoredViewModel.textOptions.fontFamily == "Georgia")
        #expect(restoredViewModel.textOptions.fontSize == 27)
    }

    @Test
    func openFontSettingsShowsFontSettings() {
        let viewModel = Support.makeViewModel()

        viewModel.openFontSettings()

        #expect(viewModel.showingFontSettings)
    }

    @Test
    func invalidStoredFontFallsBackToDefaultFont() {
        Support.clearReaderDefaults()
        let settings = StoredReaderSettings(
            fontFamily: "Definitely Not A Reader Font",
            fontSize: 15,
            lineSpacing: 18,
            colorTheme: 6
        )
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: Support.readerSettingsKey)

        let viewModel = Support.makeViewModel()

        #expect(viewModel.textOptions.fontFamily == ReaderFonts.defaultFontFamily)
        #expect(viewModel.textOptions.fontSize == 15)
        #expect(viewModel.textOptions.lineSpacing == 18)
        #expect(viewModel.colorTheme == ReaderTheme.theme(withId: 6))
    }

    @Test
    func colorThemeUpdatesReaderAndVersionsViewModelsAndPersists() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()
        let theme = ReaderTheme.theme(withId: 5)

        viewModel.setColorTheme(theme)

        #expect(viewModel.colorTheme == theme)
        #expect(viewModel.versionsViewModel.colorTheme == theme)
        #expect(Support.makeViewModel().colorTheme == theme)
    }

    @Test
    func cycleLineSpacingCyclesThroughOptionsAndPersists() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()

        viewModel.cycleLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 18)

        viewModel.cycleLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 6)

        #expect(Support.makeViewModel().textOptions.lineSpacing == 6)
    }
}
