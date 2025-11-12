import SwiftUI

public extension Bundle {
    static var YouVersionBundle: Bundle {
        // First try to get the SPM module bundle
         #if SWIFT_PACKAGE
         return Bundle.module
         #else
         // For CocoaPods, look for the resource bundle
         let bundle = Bundle(for: BundleToken.self)
         
         if let resourceBundleURL = bundle.url(forResource: "YouVersionPlatformResources", withExtension: "bundle"),
            let resourceBundle = Bundle(url: resourceBundleURL) {
             return resourceBundle
         }
         
         // Fallback to the main bundle containing this class
         return bundle
         #endif
    }
}

// Private token class for bundle identification in CocoaPods
private final class BundleToken {}
