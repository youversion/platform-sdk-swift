import Testing
@testable import YouVersionPlatformUI

struct YouVersionFontsTests {
    @Test
    func reportsAvailableFontFamily() {
        #expect(YouVersionFonts.isFontFamilyAvailable("Helvetica"))
    }

    @Test
    func reportsUnavailableFontFamily() {
        #expect(!YouVersionFonts.isFontFamilyAvailable("Definitely Not A Font Family"))
    }
}
