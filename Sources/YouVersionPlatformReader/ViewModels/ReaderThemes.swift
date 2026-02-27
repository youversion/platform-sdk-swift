import Foundation
import SwiftUI

struct ReaderTheme: Identifiable {
    let id: Int
    let foreground: Color
    let background: Color
    let colorScheme: ColorScheme

    static func == (lhs: ReaderTheme, rhs: ReaderTheme) -> Bool {
        lhs.foreground == rhs.foreground && lhs.background == rhs.background
    }

    static let allThemes: [ReaderTheme] = [
        ReaderTheme(id: 1, foreground: Color(hex: "#121212"), background: Color(hex: "#ffffff"), colorScheme: .light),
        ReaderTheme(id: 2, foreground: Color(hex: "#121212"), background: Color(hex: "#f6efee"), colorScheme: .light),
        ReaderTheme(id: 3, foreground: Color(hex: "#121212"), background: Color(hex: "#edefef"), colorScheme: .light),
        ReaderTheme(id: 4, foreground: Color(hex: "#121212"), background: Color(hex: "#fef5eb"), colorScheme: .light),
        ReaderTheme(id: 5, foreground: Color(hex: "#ffffff"), background: Color(hex: "#2b3031"), colorScheme: .dark),
        ReaderTheme(id: 6, foreground: Color(hex: "#ffffff"), background: Color(hex: "#1c2a3b"), colorScheme: .dark),
        ReaderTheme(id: 7, foreground: Color(hex: "#ffffff"), background: Color(hex: "#121212"), colorScheme: .dark)
    ]

    static func theme(withId: Int? = nil) -> ReaderTheme {
        allThemes.first(where: { $0.id == withId }) ?? allThemes.first!
    }
}

extension BibleReaderViewModel {
    func colorForScheme(light: Color, dark: Color) -> Color {
        colorTheme?.colorScheme == .dark ? dark : light
    }

    var readerCanvasPrimaryColor: Color {
        colorTheme?.background ?? (colorTheme?.colorScheme != .dark ? readerWhiteColor : readerBlackColor)
    }

    var readerTextPrimaryColor: Color {
        colorTheme?.foreground ?? (colorTheme?.colorScheme != .dark ? readerBlackColor : readerWhiteColor)
    }

    var readerVerseNumColor: Color {
        colorTheme?.colorScheme != .dark ? Color(hex: "#9d9d9d") : Color(hex: "#636161")
    }

    var readerTextMutedColor: Color {
        readerTextPrimaryColor == readerWhiteColor ? Color(hex: "#636161") : Color(hex: "#bfbdbd")
    }

    var readerSurfacePrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "f6f4f4"),
            dark: Color(hex: "232121")
        )
    }

    var readerSurfaceTertiaryColor: Color {
        colorForScheme(
            light: Color(hex: "EDEBEB"),
            dark: Color(hex: "353333")
        )
    }

    var readerBorderPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    var readerBorderSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "bfbdbd"),
            dark: Color(hex: "636161")
        )
    }

    var readerButtonPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "#edebeb"),
            dark: Color(hex: "#353333")
        )
    }

    var readerButtonSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    var readerButtonContrastColor: Color {
        colorForScheme(
            light: Color(hex: "121212"),
            dark: Color(hex: "edebeb")
        )
    }

    var readerTextInvertedColor: Color {
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

    var readerDropShadowColor: Color {
        Color(hex: "#777777").opacity(0.5)
    }

    var readerWordsOfChristColor: Color {
        colorForScheme(
            light: Color(hex: "#ff3d4d"),
            dark: Color(hex: "#F04C59")
        )
    }
}
