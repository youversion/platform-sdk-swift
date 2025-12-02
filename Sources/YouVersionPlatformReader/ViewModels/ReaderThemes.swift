import Foundation
import SwiftUI

struct ReaderTheme: Identifiable {
    let id = UUID()
    let foreground: Color
    let background: Color
    let colorScheme: ColorScheme

    static func == (lhs: ReaderTheme, rhs: ReaderTheme) -> Bool {
        lhs.foreground == rhs.foreground && lhs.background == rhs.background
    }

    static let allThemes: [ReaderTheme] = [
        ReaderTheme(foreground: Color(hex: "#121212"), background: Color(hex: "#ffffff"), colorScheme: .light),
        ReaderTheme(foreground: Color(hex: "#121212"), background: Color(hex: "#f6efee"), colorScheme: .light),
        ReaderTheme(foreground: Color(hex: "#121212"), background: Color(hex: "#edefef"), colorScheme: .light),
        ReaderTheme(foreground: Color(hex: "#121212"), background: Color(hex: "#fef5eb"), colorScheme: .light),
        ReaderTheme(foreground: Color(hex: "#ffffff"), background: Color(hex: "#2b3031"), colorScheme: .dark),
        ReaderTheme(foreground: Color(hex: "#ffffff"), background: Color(hex: "#1c2a3b"), colorScheme: .dark),
        ReaderTheme(foreground: Color(hex: "#ffffff"), background: Color(hex: "#121212"), colorScheme: .dark)
    ]
}

extension BibleReaderViewModel {
    func colorForScheme(light: Color, dark: Color) -> Color {
        colorTheme?.colorScheme == .dark ? dark : light
    }

    var surfacePrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "f6f4f4"),
            dark: Color(hex: "232121")
        )
    }

    var surfaceTertiaryColor: Color {
        colorForScheme(
            light: Color(hex: "EDEBEB"),
            dark: Color(hex: "353333")
        )
    }

    var borderPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    var borderSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "bfbdbd"),
            dark: Color(hex: "636161")
        )
    }

    var buttonPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "#edebeb"),
            dark: Color(hex: "#353333")
        )
    }

    var buttonSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    var buttonContrastColor: Color {
        colorForScheme(
            light: Color(hex: "121212"),
            dark: Color(hex: "edebeb")
        )
    }

    var textInvertedColor: Color {
        colorForScheme(
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
        colorForScheme(
            light: Color(hex: "#ff3d4d"),
            dark: Color(hex: "#F04C59")
        )
    }
}
