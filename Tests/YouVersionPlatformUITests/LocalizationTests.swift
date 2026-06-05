import Foundation
import Testing
import YouVersionPlatformUI

@Suite struct LocalizationTests {
    @Test
    func englishDefaultCancelIsTranslated() {
        let value = String.localized("generic.cancel")

        #expect(value == "Cancel")
        #expect(value != "generic.cancel")
    }

    @Test
    func germanStringsAreTranslated() {
        #expect(
            localizedString(forKey: "generic.cancel", languageCode: "de") == "Abbrechen"
        )
        #expect(
            localizedString(forKey: "bookChapterPicker.title", languageCode: "de") == "Bücher"
        )
    }

    @Test
    func frenchAndSpanishMexicoCancelAreTranslated() {
        #expect(
            localizedString(forKey: "generic.cancel", languageCode: "fr") == "Annuler"
        )
        #expect(
            localizedString(forKey: "generic.cancel", languageCode: "es-MX") == "Cancelar"
        )
    }

    @Test
    func germanSignInButtonFormatStringInsertsAppName() {
        let format = localizedString(forKey: "signIn.button.full", languageCode: "de")
        let value = String(format: format, "YouVersion")

        #expect(value == "Mit YouVersion anmelden")
    }

    @Test
    func youVersionUIBundleContainsExpectedLanguageBundles() {
        let bundle = Bundle.YouVersionUIBundle

        for languageCode in ["de", "fr", "es-MX"] {
            #expect(bundle.path(forResource: languageCode, ofType: "lproj") != nil)
        }
    }

    @Test
    func genericOkIsTranslatedInEnglish() {
        #expect(
            localizedString(forKey: "generic.ok", languageCode: "en") == "OK"
        )
    }
}

private func localizedString(
    forKey key: String,
    languageCode: String,
    bundle: Bundle = .YouVersionUIBundle
) -> String {
    guard let lprojPath = bundle.path(forResource: languageCode, ofType: "lproj"),
          let localizedBundle = Bundle(path: lprojPath) else {
        Issue.record("Missing \(languageCode).lproj in \(bundle.bundlePath)")
        return key
    }
    return localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
}
