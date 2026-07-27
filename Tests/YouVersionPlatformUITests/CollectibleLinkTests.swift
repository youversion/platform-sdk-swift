import Foundation
import Testing
@testable import YouVersionPlatformUI

@MainActor
@Suite struct CollectibleLinkTests {

    @Test("Simple id round-trips")
    func simpleRoundTrip() {
        let url = BibleVersionRendering.collectibleLink(id: "42")
        #expect(url?.scheme == BibleVersionRendering.LinkSchemes.collectible.rawValue)
        #expect(url.flatMap(BibleVersionRendering.collectibleID(from:)) == "42")
    }

    @Test("Ids with spaces, slashes, and mixed case round-trip intact")
    func specialCharactersRoundTrip() {
        for id in ["collectibles/42", "Sea of Galilee", "AbC-123_xyz", "id with spaces & symbols?"] {
            guard let url = BibleVersionRendering.collectibleLink(id: id) else {
                Issue.record("Failed to build URL for id \(id)")
                continue
            }
            #expect(BibleVersionRendering.collectibleID(from: url) == id)
        }
    }

    @Test("Non-collectible URLs return nil")
    func nonCollectibleReturnsNil() {
        #expect(BibleVersionRendering.collectibleID(from: URL(string: "footnote://111/JHN.1.1")!) == nil)
        #expect(BibleVersionRendering.collectibleID(from: URL(string: "https://example.com")!) == nil)
    }
}
