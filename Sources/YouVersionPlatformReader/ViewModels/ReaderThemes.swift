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
