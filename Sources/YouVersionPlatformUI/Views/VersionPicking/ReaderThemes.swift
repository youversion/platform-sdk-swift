import Foundation
import SwiftUI

public struct ReaderTheme: Identifiable, Equatable, Sendable {
    public let id: Int
    public let foreground: Color
    public let background: Color
    public let colorScheme: ColorScheme

    public static func == (lhs: ReaderTheme, rhs: ReaderTheme) -> Bool {
        lhs.foreground == rhs.foreground && lhs.background == rhs.background
    }

    public static let allThemes: [ReaderTheme] = [
        ReaderTheme(id: 1, foreground: Color(hex: "#121212"), background: Color(hex: "#ffffff"), colorScheme: .light),
        ReaderTheme(id: 2, foreground: Color(hex: "#121212"), background: Color(hex: "#f6efee"), colorScheme: .light),
        ReaderTheme(id: 3, foreground: Color(hex: "#121212"), background: Color(hex: "#edefef"), colorScheme: .light),
        ReaderTheme(id: 4, foreground: Color(hex: "#121212"), background: Color(hex: "#fef5eb"), colorScheme: .light),
        ReaderTheme(id: 5, foreground: Color(hex: "#ffffff"), background: Color(hex: "#2b3031"), colorScheme: .dark),
        ReaderTheme(id: 6, foreground: Color(hex: "#ffffff"), background: Color(hex: "#1c2a3b"), colorScheme: .dark),
        ReaderTheme(id: 7, foreground: Color(hex: "#ffffff"), background: Color(hex: "#121212"), colorScheme: .dark)
    ]

    public static func theme(withId: Int? = nil) -> ReaderTheme {
        allThemes.first(where: { $0.id == withId }) ?? allThemes.first!
    }
}

@MainActor
public protocol ReaderThemeProviding {
    var colorTheme: ReaderTheme? { get }
}

@MainActor
extension ReaderThemeProviding {
    public func colorForScheme(light: Color, dark: Color) -> Color {
        colorTheme?.colorScheme == .dark ? dark : light
    }

    public var readerCanvasPrimaryColor: Color {
        colorTheme?.background ?? (colorTheme?.colorScheme != .dark ? readerWhiteColor : readerBlackColor)
    }

    public var readerTextPrimaryColor: Color {
        colorTheme?.foreground ?? (colorTheme?.colorScheme != .dark ? readerBlackColor : readerWhiteColor)
    }

    public var readerVerseNumColor: Color {
        colorTheme?.colorScheme != .dark ? Color(hex: "#9d9d9d") : Color(hex: "#636161")
    }

    public var readerTextMutedColor: Color {
        readerTextPrimaryColor == readerWhiteColor ? Color(hex: "#636161") : Color(hex: "#bfbdbd")
    }

    public var readerSurfacePrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "f6f4f4"),
            dark: Color(hex: "232121")
        )
    }

    public var readerSurfaceTertiaryColor: Color {
        colorForScheme(
            light: Color(hex: "EDEBEB"),
            dark: Color(hex: "353333")
        )
    }

    public var readerBorderPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    public var readerBorderSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "bfbdbd"),
            dark: Color(hex: "636161")
        )
    }

    public var readerButtonPrimaryColor: Color {
        colorForScheme(
            light: Color(hex: "#edebeb"),
            dark: Color(hex: "#353333")
        )
    }

    public var readerButtonSecondaryColor: Color {
        colorForScheme(
            light: Color(hex: "dddbdb"),
            dark: Color(hex: "474545")
        )
    }

    public var readerButtonContrastColor: Color {
        colorForScheme(
            light: Color(hex: "121212"),
            dark: Color(hex: "edebeb")
        )
    }

    public var readerTextInvertedColor: Color {
        colorForScheme(
            light: readerWhiteColor,
            dark: readerBlackColor
        )
    }

    public var readerWhiteColor: Color {
        Color(hex: "#ffffff")
    }

    public var readerBlackColor: Color {
        Color(hex: "#121212")
    }

    public var readerDropShadowColor: Color {
        Color(hex: "#777777").opacity(0.5)
    }

    public var readerWordsOfChristColor: Color {
        colorForScheme(
            light: Color(hex: "#ff3d4d"),
            dark: Color(hex: "#F04C59")
        )
    }
}

extension BibleVersionsViewModel: ReaderThemeProviding {}
