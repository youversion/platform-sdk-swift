import SwiftUI

public extension Bundle {
    static var YouVersionReaderBundle: Bundle {
         #if SWIFT_PACKAGE
         return Bundle.module
         #else
         return Bundle.YouVersionUIBundle
         #endif
    }
}
