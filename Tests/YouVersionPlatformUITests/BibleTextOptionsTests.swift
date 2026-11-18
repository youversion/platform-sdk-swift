import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import YouVersionPlatformUI

@Suite struct BibleTextOptionsTests {
#if canImport(UIKit)
    @Test(arguments: [
        (UIUserInterfaceStyle.light, "94000C"),
        (UIUserInterfaceStyle.dark, "E4BFC2")
    ])
    func defaultWordsOfChristColorMatchesOtherSDKs(style: UIUserInterfaceStyle, expectedHex: String) {
        let color = UIColor(BibleTextOptions().wordsOfChristColor)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        #expect(Color(uiColor: color).hexString == expectedHex)
    }
#endif
}
