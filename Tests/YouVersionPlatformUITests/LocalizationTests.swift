import Foundation
import Testing
import YouVersionPlatformUI

@Suite struct LocalizationTests {
    @Test
    func englishDefaultCancelIsTranslated() {
        let value = localizedString(forKey: "generic.cancel", languageCode: "en")

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
    func youVersionUIBundleContainsExpectedLocalizations() {
        for languageCode in ["de", "fr", "es-MX"] {
            #expect(
                localizedString(forKey: "generic.cancel", languageCode: languageCode) != "generic.cancel"
            )
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
    if let lprojPath = bundle.path(forResource: languageCode, ofType: "lproj"),
       let localizedBundle = Bundle(path: lprojPath) {
        return localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    if let value = stringCatalogLocalizedString(forKey: key, languageCode: languageCode, bundle: bundle) {
        return value
    }

    Issue.record("Missing \(languageCode) localization for \(key) in \(bundle.bundlePath)")
    return key
}

private func stringCatalogLocalizedString(
    forKey key: String,
    languageCode: String,
    bundle: Bundle
) -> String? {
    guard let url = bundle.url(forResource: "Localizable", withExtension: "xcstrings") else {
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        guard let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = catalog["strings"] as? [String: Any],
              let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[languageCode] as? [String: Any],
              let stringUnit = localization["stringUnit"] as? [String: Any],
              let value = stringUnit["value"] as? String else {
            return nil
        }
        return value
    } catch {
        Issue.record("Unable to read Localizable.xcstrings in \(bundle.bundlePath): \(error)")
        return nil
    }
}
