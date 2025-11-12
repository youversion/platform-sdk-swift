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
    
    var surfacePrimaryColor: Color {
        Color(
            light: Color(hex: "f6f4f4"),
            dark: Color(hex: "232121")
        )
    }
    
    var surfaceTertiaryColor: Color {
        Color(
            light: Color(hex: "EDEBEB"),
            dark: Color(hex: "353333")
        )
    }
    
    var borderPrimaryColor: Color {
        Color(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }
    
    var borderSecondaryColor: Color {
        Color(
            light: Color(hex: "bfbdbd"),
            dark: Color(hex: "636161")
        )
    }
    
    var buttonPrimaryColor: Color {
        Color(
            light: Color(hex: "#edebeb"),
            dark: Color(hex: "#353333")
        )
    }
    
    var buttonSecondaryColor: Color {
        Color(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }
    
    var buttonContrastColor: Color {
        Color(
            light: Color(hex: "121212"),
            dark: Color(hex: "edebeb")
        )
    }
    
    var textInvertedColor: Color {
        Color(
            light: readerWhiteColor,
            dark: readerBlackColor
        )
    }
    
    var readerWhiteColor: Color {
        Color(hex: "#ffffff")
    }
    
    var readerBlackColor: Color {
        Color(hex: "#121212")
    }

    var dropShadowColor: Color {
        Color(hex: "#777777").opacity(0.5)
    }
    
    var wordsOfChristColor: Color {
        Color(
            light: Color(hex: "#ff3d4d"),
            dark: Color(hex: "#F04C59")
        )
    }
}
