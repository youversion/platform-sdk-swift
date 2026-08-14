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
        let savedReference = BibleReference(versionId: 111, bookId: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Support.referenceKey)

        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1)
        )

        #expect(viewModel.reference == BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func initWithoutExplicitReferenceRestoresSavedReferenceAndIntroState() {
        Support.clearReaderDefaults()
        let savedReference = BibleReference(versionId: 111, bookId: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Support.referenceKey)
        UserDefaults.standard.set(true, forKey: Support.displayIntroKey)

        let viewModel = Support.makeViewModel(reference: nil)

        #expect(viewModel.reference == savedReference)
        #expect(viewModel.showBookIntro)
    }

    @Test
    func initWithoutExplicitReferenceRestoresSavedShowsFullChapter() {
        Support.clearReaderDefaults()
        let savedReference = BibleReference(versionId: 111, bookId: "JHN", chapter: 3, verse: 16)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Support.referenceKey)
        UserDefaults.standard.set(true, forKey: Support.showsFullChapterKey)

        let viewModel = Support.makeViewModel(reference: nil)

        #expect(viewModel.reference == savedReference)
        #expect(viewModel.showsFullChapter)
    }

    @Test
    func initWithExplicitReferenceIgnoresSavedShowsFullChapter() {
        Support.clearReaderDefaults()
        UserDefaults.standard.set(true, forKey: Support.showsFullChapterKey)

        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1),
            showsFullChapter: false
        )

        #expect(viewModel.showsFullChapter == false)
    }

    @Test
    func showsFullChapterPersistsWhenChanged() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookId: "GEN", chapter: 1)
        )

        viewModel.showsFullChapter = true

        #expect(UserDefaults.standard.bool(forKey: Support.showsFullChapterKey))
    }

    @Test
    func initWithoutSavedReferenceUsesDefaultJohnOneReference() {
        Support.clearReaderDefaults()

        let viewModel = Support.makeViewModel(reference: nil)

        #expect(viewModel.reference == BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func referenceAndShowBookIntroPersistWhenChanged() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(
            reference: BibleReference(versionId: Support.versionId, bookId: "GEN", chapter: 1)
        )

        let newReference = BibleReference(versionId: Support.versionId, bookId: "ROM", chapter: 8)
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

        #expect(viewModel.textOptions.fontSize == 18)
        #expect(viewModel.textOptions.lineSpacing == ReaderFonts.defaultLineSpacing)

        viewModel.decreaseFontSize()
        #expect(viewModel.textOptions.fontSize == 15)

        viewModel.increaseFontSize()
        #expect(viewModel.textOptions.fontSize == 18)

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
        #expect(viewModel.colorTheme == ReaderTheme.theme(withId: 6))
    }

    @Test
    func currentLineSpacingValuesRestoreWithoutModification() throws {
        for lineSpacing in ReaderFonts.lineSpacingOptions {
            Support.clearReaderDefaults()
            let settings = StoredReaderSettings(
                fontFamily: "Georgia",
                fontSize: 15,
                lineSpacing: lineSpacing,
                colorTheme: 6
            )
            let savedData = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(savedData, forKey: Support.readerSettingsKey)

            let viewModel = Support.makeViewModel()

            #expect(viewModel.textOptions.lineSpacing == lineSpacing)
            #expect(UserDefaults.standard.data(forKey: Support.readerSettingsKey) == savedData)
        }
    }

    @Test
    func missingLineSpacingUsesDefaultWithoutModifyingStoredSettings() throws {
        Support.clearReaderDefaults()
        let settings = StoredReaderSettings(
            fontFamily: "Georgia",
            fontSize: 15,
            lineSpacing: nil,
            colorTheme: 6
        )
        let savedData = try JSONEncoder().encode(settings)
        UserDefaults.standard.set(savedData, forKey: Support.readerSettingsKey)

        let viewModel = Support.makeViewModel()

        #expect(viewModel.textOptions.lineSpacing == ReaderFonts.defaultLineSpacing)
        #expect(UserDefaults.standard.data(forKey: Support.readerSettingsKey) == savedData)
    }

    @Test
    func legacyLineSpacingValuesMigrateAndPersist() throws {
        let migrations: [(legacy: CGFloat, current: CGFloat)] = [
            (6, 0.3),
            (12, 0.4),
            (18, 0.6),
        ]

        for migration in migrations {
            Support.clearReaderDefaults()
            let settings = StoredReaderSettings(
                fontFamily: "Georgia",
                fontSize: 15,
                lineSpacing: migration.legacy,
                colorTheme: 6
            )
            UserDefaults.standard.set(try JSONEncoder().encode(settings), forKey: Support.readerSettingsKey)

            let viewModel = Support.makeViewModel()
            let migratedSettings = try storedReaderSettings()

            #expect(viewModel.textOptions.lineSpacing == migration.current)
            #expect(migratedSettings.lineSpacing == migration.current)
        }
    }

    @Test
    func invalidLineSpacingValuesFallBackToDefaultAndPersist() throws {
        for invalidLineSpacing: CGFloat in [-1, 0, 0.5, 999] {
            Support.clearReaderDefaults()
            let settings = StoredReaderSettings(
                fontFamily: "Georgia",
                fontSize: 15,
                lineSpacing: invalidLineSpacing,
                colorTheme: 6
            )
            UserDefaults.standard.set(try JSONEncoder().encode(settings), forKey: Support.readerSettingsKey)

            let viewModel = Support.makeViewModel()
            let migratedSettings = try storedReaderSettings()

            #expect(viewModel.textOptions.lineSpacing == ReaderFonts.defaultLineSpacing)
            #expect(migratedSettings.lineSpacing == ReaderFonts.defaultLineSpacing)
        }
    }

    @Test
    func malformedStoredSettingsUseFreshDefaults() {
        Support.clearReaderDefaults()
        let malformedData = Data("not json".utf8)
        UserDefaults.standard.set(malformedData, forKey: Support.readerSettingsKey)

        let viewModel = Support.makeViewModel()

        #expect(viewModel.textOptions.fontFamily == ReaderFonts.defaultFontFamily)
        #expect(viewModel.textOptions.fontSize == ReaderFonts.defaultFontSize)
        #expect(viewModel.textOptions.lineSpacing == ReaderFonts.defaultLineSpacing)
        #expect(UserDefaults.standard.data(forKey: Support.readerSettingsKey) == malformedData)
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
    func colorThemeFollowsSystemSchemeWhenUserHasNotPicked() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()

        viewModel.colorScheme = .light
        #expect(viewModel.colorTheme == ColorScheme.light.readerTheme)

        viewModel.colorScheme = .dark
        #expect(viewModel.colorTheme == ColorScheme.dark.readerTheme)
    }

    @Test
    func colorThemeStaysAtUserPickWhenSystemSchemeChanges() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()
        let userPick = ReaderTheme.theme(withId: 4)

        viewModel.setColorTheme(userPick)

        viewModel.colorScheme = .light
        #expect(viewModel.colorTheme == userPick)

        viewModel.colorScheme = .dark
        #expect(viewModel.colorTheme == userPick)
    }

    @Test
    func fontChangeBeforeThemePickDoesNotPersistAThemeId() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()

        viewModel.increaseFontSize()

        // Nothing about the theme was persisted, so a fresh view model still
        // follows the system color scheme rather than being locked to a
        // stored theme: toggling its colorScheme moves colorTheme with it.
        let restored = Support.makeViewModel()
        restored.colorScheme = .light
        #expect(restored.colorTheme == ColorScheme.light.readerTheme)
        restored.colorScheme = .dark
        #expect(restored.colorTheme == ColorScheme.dark.readerTheme)
    }

    @Test
    func cycleLineSpacingCyclesThroughOptionsAndPersists() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()

        viewModel.cycleLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 0.6)

        viewModel.cycleLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 0.3)
    }

    private func storedReaderSettings() throws -> StoredReaderSettings {
        let data = try #require(UserDefaults.standard.data(forKey: Support.readerSettingsKey))
        return try JSONDecoder().decode(StoredReaderSettings.self, from: data)
    }
}
