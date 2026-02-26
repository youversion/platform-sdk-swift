import SwiftUI
import YouVersionPlatformCore

public final class BibleAttributedString: Equatable, Hashable {
    private var two: AttributedString

    public init() {
        two = AttributedString()
    }

    public init(_ string: String) {
        two = AttributedString(string)
    }

    static func +(lhs: BibleAttributedString, rhs: BibleAttributedString) -> BibleAttributedString { //swiftlint:disable:this function_name_whitespace
        let result = BibleAttributedString()
        result.two = lhs.two + rhs.two
        return result
    }

    static func += (lhs: inout BibleAttributedString, rhs: BibleAttributedString) {
        lhs = lhs + rhs
    }

    public static func == (lhs: BibleAttributedString, rhs: BibleAttributedString) -> Bool {
        lhs.two == rhs.two
    }

    public func hash(into hasher: inout Hasher) {
        two.hash(into: &hasher)
    }

    public var asAttributedString: AttributedString {
        two
    }

    var characters: String {
        String(two.characters)
    }

    var isEmpty: Bool {
        two.characters.isEmpty
    }

    @discardableResult
    public func setFont(_ option: BibleTextFontOption, from fonts: BibleTextFonts) -> BibleAttributedString {
        two.font = fonts.font(for: option)
        return self
    }

    @discardableResult
    public func setColor(_ color: Color) -> BibleAttributedString {
        var ac = AttributeContainer()
        ac.foregroundColor = color
        two.mergeAttributes(ac)
        return self
    }

    @discardableResult
    public func setBaselineOffset(_ offset: CGFloat) -> BibleAttributedString {
        two.baselineOffset = offset
        return self
    }

    func trimTrailingWhitespaceAndNewlines() {
        var trimmed = two
        while let last = trimmed.characters.last, last.isWhitespace {
            trimmed = AttributedString(trimmed.characters.dropLast())
        }
        two = trimmed
    }

    func markWithTextCategory(_ category: BibleTextCategory) {
        two.bibleTextCategory = category
    }

    func markWithReference(_ reference: BibleReference, scheme: String, id: String?) {
        two.bibleReference = reference
        let idString = id == nil ? "" : "#\(id!)"
        two.link = URL(string: "\(scheme)://\(reference.versionId)/\(reference.asUSFM)\(idString)")
    }

}
