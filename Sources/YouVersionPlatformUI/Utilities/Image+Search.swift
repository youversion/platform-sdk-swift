import SwiftUI

extension Image {
    package static var magnifyingGlass: Image {
        Image("magnifying-glass", bundle: .YouVersionUIBundle)
            .renderingMode(.template)
    }
}
