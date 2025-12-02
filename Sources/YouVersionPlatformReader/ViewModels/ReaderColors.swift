import Foundation
import SwiftUI
import YouVersionPlatformCore
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    #if canImport(UIKit)
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
            UIColor(dark) : UIColor(light)
        })
    }
    #else
    init(light: Color, dark: Color) {
        self = light
    }
    #endif
}

protocol ReaderColors {}
extension ReaderColors {
}
