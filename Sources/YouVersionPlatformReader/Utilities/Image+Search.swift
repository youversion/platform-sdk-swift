import SwiftUI
import YouVersionPlatformUI

extension Image {
    static var magnifyingGlass: Image {
        Image("magnifying-glass", bundle: .YouVersionUIBundle)
            .renderingMode(.template)
    }
}
