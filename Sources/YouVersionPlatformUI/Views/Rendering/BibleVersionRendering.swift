#if canImport(SwiftUI)
import SwiftUI
import YouVersionPlatformCore

// Marked as @MainActor due to NSMutableAttributedStrings in BibleTextBlocks.
@MainActor
public enum BibleVersionRendering {

    /// Returns nil if the chapter data is unavailable (e.g. we're offline).
    /// Throws YouVersionAPIError.notPermitted if access to the Bible version is denied.
    public static func plainTextOf(_ reference: BibleReference) async throws -> String? {
        // the fonts aren't used in this case, but are required.
        let familyName = "Times New Roman"
        do {
            guard let blocks = try await textBlocks(
                reference,
                renderVerseNumbers: false,
                renderHeadlines: false,
                renderFootnotes: false,
                fonts: BibleTextFonts(familyName: familyName)
            ) else {
                return nil
            }
            return blocks.map { String($0.text.characters) }.joined(separator: "\n")
        } catch YouVersionAPIError.notPermitted {
            throw YouVersionAPIError.notPermitted
        } catch {
            return nil
        }
    }

    /// Formats the Bible data into AttributedString objects plus metadata.
    /// If the chapter data is unavailable (e.g. we're offline), this returns nil.
    static func textBlocks(
        _ reference: BibleReference,
        renderVerseNumbers: Bool = true,
        renderHeadlines: Bool = true,
        renderFootnotes: Bool = false,
        footnoteMarker: BibleAttributedString? = nil,
        textColor: Color = Color.primary,
        wocColor: Color = Color.red,
        fonts: BibleTextFonts
    ) async throws -> [BibleTextBlock]? {
        let book = reference.bookUSFM
        let c = reference.chapter
        let chapterReference = BibleReference(versionId: reference.versionId, bookUSFM: book, chapter: c)

        let rootNode: BibleTextNode?
        do {
            let data = try await BibleChapterRepository.shared.chapter(withReference: chapterReference)
            var node = try? BibleTextNode.parse(data)
            if node?.children.count ?? 0 == 0 {
                print("cached chapter data seems bad. Removing it and retrying.")
                await BibleChapterRepository.shared.removeVersion(withId: reference.versionId)
                let data = try await BibleChapterRepository.shared.chapter(withReference: chapterReference)
                node = try? BibleTextNode.parse(data)
            }
            rootNode = node
        } catch YouVersionAPIError.notPermitted {
            throw YouVersionAPIError.notPermitted
        } catch {
            return nil
        }
        guard let rootNode, !rootNode.children.isEmpty else {
            return nil
        }

        var ret: [BibleTextBlock] = []
        let verseStart = reference.verseStart ?? 1
        let verseEnd = reference.verseEnd ?? 999

        let marker = footnoteMarker
        if marker != nil {
            marker!.setFont(.footnote, from: fonts)
            marker!.markWithTextCategory(.footnoteMarker)
        }
        let stateIn = StateIn(
            versionId: reference.versionId,
            bookUSFM: reference.bookUSFM,
            currentChapter: reference.chapter,
            fromVerse: verseStart,
            toVerse: verseEnd,
            renderVerseNumbers: renderVerseNumbers,
            renderHeadlines: renderHeadlines,
            renderFootnotes: renderFootnotes,
            footnoteMarker: marker,
            textColor: textColor,
            wocColor: wocColor,
            fonts: fonts
        )
        let stateDown = StateDown(
            woc: false,
            smallcaps: false,
            alignment: .leading,
            currentFont: .textFont,
            textCategory: .scripture,
            nodeDepth: 0
        )
        var stateUp = StateUp(
            rendering: verseStart <= 1,
            firstLineHeadIndent: 0,
            headIndent: 0,
            versionId: reference.versionId,
            bookUSFM: reference.bookUSFM,
            chapter: c,
            verse: 0
        )

        if let firstChild = rootNode.children.first {
            handleNodeBlock(
                node: firstChild,
                stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp,
                ret: &ret
            )
        }
        return ret
    }

    private static func traceLog(_ node: BibleTextNode, stateDown: StateDown) {
        #if false
        // enable this for debugging/tracing this rendering code

        let nodeType = switch node.type {
        case .block: "block"
        case .table: "table"
        case .row: "row"
        case .cell: "cell"
        case .text: "text"
        case .span: "span"
        default:
            "unknown"
        }

        print("\(String(repeating: "__", count: stateDown.nodeDepth)) \(nodeType.padding(toLength: 6, withPad: " ", startingAt: 0)) \(node.classes) \(node.attributes) [\(node.text)]")
        #endif
    }

    private static func handleBlockChild(
        _ node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp
    ) {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        traceLog(node, stateDown: stateDown)
        if node.type != .span && node.type != .text {
            assertionFailed("handleBlockChild: unexpected:", type: node.type)
        }

        interpretTextAttr(node, stateIn: stateIn, stateDown: &stateDown, stateUp: &stateUp)

        if stateUp.rendering && !node.text.isEmpty {
            var txt = BibleAttributedString(node.text)
            if node.text == "  " {
                // It feels odd for us to do this check, but extra spaces are present in the source,
                // after footnotes e.g. NIV Acts 1:4, and at ends of some verses e.g. Acts 1:7.
                // The concept is/was HTML, which does this collapsing internally.
                txt = BibleAttributedString(" ")
            }
            txt.setFont(stateDown.currentFont, from: stateIn.fonts)
            if stateDown.woc {
                txt.setColor(stateIn.wocColor)
            }
            stateUp.append(txt, category: stateDown.textCategory)
        }

        if stateUp.rendering &&
            (node.classes.contains("yv-vlbl") || node.classes.contains("vlbl"))
            && node.children.count == 1 && node.children.first?.type == .text {
            if let t = node.children.first?.text {
                if stateIn.renderVerseNumbers {
                    let maybeSpace = stateUp.isTextEmpty || stateUp.endsWithASpace ? "" : " "
                    let vn = BibleAttributedString(maybeSpace + t + "\u{00a0}")  // nonbreaking space
                    vn.setFont(.verseNumFont, from: stateIn.fonts)
                    vn.setBaselineOffset(stateIn.fonts.verseNumBaselineOffset)
                    vn.setColor(stateIn.textColor.opacity(stateIn.fonts.verseNumOpacity))
                    stateUp.append(vn, category: .verseLabel)
                }
            }
        } else if node.classes.contains("rq") {
            // a cross-reference, e.g. NIrV (#110) Revelation 19:15. Not really a footnote; something different.
        } else if node.classes.contains("yv-n") && node.classes.contains("f") {
            if stateUp.rendering && stateIn.renderFootnotes {
                handleFootnoteNode(node, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
            }
        } else if node.classes.contains("yv-n") && node.classes.contains("x") {
            // cross-reference; present e.g. in ESV
        } else {
            for child in node.children {
                handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
            }
        }
    }

    private static func handleFootnoteNode(
        _ node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp
    ) {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        stateDown.textCategory = .footnoteText
        if let marker = stateIn.footnoteMarker {
            stateUp.append(marker, category: .footnoteMarker)
            // now, collect the text of the footnotes into footState
            var footState = StateUp(
                rendering: true,
                versionId: stateUp.versionId,
                bookUSFM: stateUp.bookUSFM,
                chapter: stateUp.chapter,
                verse: stateUp.verse
            )
            stateDown.currentFont = .footnote
            for child in node.children {
                handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &footState)
            }
            stateUp.footnotes.append(footState.text)
        } else {
            for child in node.children {
                stateDown.currentFont = .footnote
                handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
            }
            // TODO: add a space here? Maybe only if it doesn't already end with whitespace?
        }
    }

    private static func handleNodeCell(
        node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp
    ) {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        traceLog(node, stateDown: stateDown)
        for child in node.children {
            if child.type == .span || child.type == .text {
                stateDown.currentFont = .textFont
                handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
                // handleBlockChild puts its result into stateUp.text
            } else {
                assertionFailed("unexpected child of cell: ", type: child.type)
            }
        }
    }

    private static func handleNodeRow(
        node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp
    ) -> [BibleAttributedString] {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        traceLog(node, stateDown: stateDown)

        var thisRow: [BibleAttributedString] = []
        for child in node.children {
            if child.type == .cell {
                handleNodeCell(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
                if stateUp.rendering {
                    stateUp.text.trimTrailingWhitespaceAndNewlines()
                    thisRow.append(stateUp.text)
                    stateUp.clearText()
                }
            } else {
                assertionFailed("unexpected child of row: ", type: child.type)
            }
        }
        return thisRow
    }

    private static func handleNodeTable(
        node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp,
        ret: inout [BibleTextBlock]
    ) {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        traceLog(node, stateDown: stateDown)
        var rows: [[BibleAttributedString]] = []

        if !node.classes.isEmpty {
            assertionFailed("unexpected classes for this table: ", string: "\(node.classes)")
        }
        for child in node.children {
            if child.type == .row {
                let row = handleNodeRow(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
                if !row.isEmpty {
                    rows.append(row)
                }
            } else {
                assertionFailed("unexpected child of table: ", type: child.type)
            }
        }
        if !rows.isEmpty {
            ret.append(
                BibleTextBlock(
                    text: BibleAttributedString(),
                    chapter: stateUp.chapter,
                    firstLineHeadIndent: 0, headIndent: 0, marginTop: 10,
                    alignment: .leading,
                    footnotes: stateUp.footnotes,
                    rows: rows
                )
            )
        }
    }

    private static func handleNodeBlock(
        node: BibleTextNode,
        stateIn: StateIn,
        stateDown parentStateDown: StateDown,
        stateUp: inout StateUp,
        ret: inout [BibleTextBlock]
    ) {
        var stateDown = parentStateDown
        stateDown.nodeDepth += 1
        var marginTop: CGFloat = 0
        stateDown.currentFont = .textFont

        if node.type != .block {  // TODO maybe just bail if it's not a block. Or assert.
            assertionFailed("unexpected: handleNodeBlock was given: ", type: node.type)
            return
        }
        traceLog(node, stateDown: stateDown)
        if node.classes.contains("cl") {
            // "cl" means: Chapter label used for versions that add a word such
            // as "Chapter"... we show that another way in our UI.
            return
        }

        interpretBlockClasses(
            node.classes,
            stateIn: stateIn,
            stateDown: &stateDown,
            stateUp: &stateUp,
            marginTop: &marginTop
        )

        for child in node.children {
            if child.type == .block || child.type == .table {
                if !stateUp.isTextEmpty {
                    if stateUp.rendering {
                        ret.append(createBlock(stateDown: stateDown, stateUp: &stateUp, marginTop: marginTop))
                    }
                    stateUp.clearText()
                }
                if child.type == .block {
                    handleNodeBlock(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp, ret: &ret)
                } else if child.type == .table {
                    handleNodeTable(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp, ret: &ret)
                }
            } else {
                if child.type == .span && child.classes.contains("qs") {  // Selah. Force a line break and right-alignment.
                    if !stateUp.isTextEmpty {
                        if stateUp.rendering {
                            ret.append(createBlock(stateDown: stateDown, stateUp: &stateUp, marginTop: marginTop))
                            stateUp.clearText()
                            //stateDown.marginTop = marginTop  // TODO
                            handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
                            var tmpStateDown = stateDown
                            tmpStateDown.alignment = .trailing
                            ret.append(createBlock(stateDown: tmpStateDown, stateUp: &stateUp, marginTop: marginTop))
                        }
                        stateUp.clearText()
                    }
                } else {
                    handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
                }
            }
        }
        if !stateUp.isTextEmpty {
            ret.append(createBlock(stateDown: stateDown, stateUp: &stateUp, marginTop: marginTop))
            stateUp.clearText()
        }
    }

    private static func createBlock(
        stateDown: StateDown,
        stateUp: inout StateUp,
        marginTop: CGFloat
    ) -> BibleTextBlock {
        let block = BibleTextBlock(
            text: stateUp.text,
            chapter: stateUp.chapter,
            firstLineHeadIndent: stateUp.firstLineHeadIndent,
            headIndent: stateUp.headIndent,
            marginTop: marginTop,
            alignment: stateDown.alignment,
            footnotes: stateUp.footnotes
        )
        stateUp.footnotes.removeAll()
        return block
    }

    private static func interpretBlockClasses(
        _ classes: [String],
        stateIn: StateIn,
        stateDown: inout StateDown,
        stateUp: inout StateUp,
        marginTop: inout CGFloat
    ) {
        let indentStep = 1
        let ignoredTags = [  // things we don't currently care about:
            "s1",  // Change line-height to 1em. Co-occurrs with "yv-h".
            "b",   // Poetry text stanza break (e.g. stanza break)
            "lh",  // A list header (introductory remark)
            "li",  // A list entry, level 1 (if single level)
            "li1", // A list entry, level 1 (if multiple levels)
            "li2", // A list entry, level 2
            "li3", // A list entry, level 3
            "li4", // A list entry, level 4
            "lf",  // List footer (introductory remark)
            "mr", "ms", "ms1", "ms2", "ms3", "ms4", "s2", "s3", "s4", "sp",  // handled inside yv-h
            "iex", // see John 7:52
            "ms1",
            "qa",
            "r",
            "sr",
            "po"
        ]

        for c in classes {
            switch c {

            case "p":
                stateUp.firstLineHeadIndent = indentStep * 2
                stateUp.headIndent = 0

            case "m", "nb":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "pr", "qr":
                stateDown.alignment = .trailing

            case "pc", "qc":
                stateDown.alignment = .center
                stateDown.smallcaps = true
                stateDown.textCategory = .header

            case "mi":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "pi", "pi1":
                stateUp.firstLineHeadIndent = indentStep
                stateUp.headIndent = 0

            case "pi2":
                stateUp.firstLineHeadIndent = indentStep * 2
                stateUp.headIndent = indentStep

            case "pi3":
                stateUp.firstLineHeadIndent = indentStep * 4
                stateUp.headIndent = indentStep * 3

            case "iq", "iq1", "q", "q1", "qm", "qm1", "li1":
                // Sadly SwiftUI cannot do this yet, but we want (0, 2 * indentStep) here.
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq2", "q2", "qm2", "li2":
                // Sadly SwiftUI cannot do this yet, but we want (indentStep, 2 * indentStep) here.
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq3", "q3", "qm3", "li3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq4", "q4", "qm4", "li4":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "pm", "pmo", "pmc", "pmr":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = indentStep * 2

            case "d":  // "d" # A Hebrew text heading, to provide description (e.g. Psalms)
                stateDown.currentFont = .headerItalic
                stateDown.textCategory = .header
                if !stateIn.renderHeadlines {
                    stateUp.rendering = false
                }

            case "yv-h", "yvh":  // yv-h meaning header
                stateDown.textCategory = .header
                marginTop = stateIn.fonts.baseSize
                if classes.contains("ms") || classes.contains("ms1") {
                    stateDown.currentFont = .header2
                } else if classes.contains("mr") {
                    stateDown.currentFont = .headerSmaller
                    marginTop = 0
                } else if classes.contains("s2") || classes.contains("ms2") {
                    stateDown.currentFont = .header2
                } else if classes.contains("s3") || classes.contains("ms3") {
                    stateDown.currentFont = .header3
                } else if classes.contains("s4") || classes.contains("ms4") {
                    stateDown.currentFont = .header4
                } else if classes.contains("sp") || classes.contains("r") || classes.contains("sr") {
                    stateDown.currentFont = .headerItalic
                } else {
                    // includes "s1" and "qa" by default; that's appropriate
                    stateDown.currentFont = .header
                }
                stateUp.firstLineHeadIndent = 0
                if !stateIn.renderHeadlines {
                    stateUp.rendering = false
                }

            default:
                if !ignoredTags.contains(c) {
                    assertionFailed("interpreting block classes: unexpected ", string: c)
                }
            }
        }
    }

    private static func interpretTextAttr(
        _ node: BibleTextNode,
        stateIn: StateIn,
        stateDown: inout StateDown,
        stateUp: inout StateUp
    ) {
        // this is a weird place to do this, but the tag is on a block, and block classes don't usually change fonts, so...
        if stateDown.smallcaps {
            stateDown.currentFont = .smallCaps
        }

        for c in node.classes {
            if c == "wj" {
                stateDown.woc = true
            } else if c == "yv-v" || c == "verse" {  // (invisible) start of a verse.
                if let v = node.attributes["v"] {
                    if let vi = Int(v) {
                        stateUp.verse = vi
                        stateUp.rendering = (vi >= stateIn.fromVerse) && (vi <= stateIn.toVerse)
                    }
                }
            } else if node.classes.contains("nd") || node.classes.contains("sc") {
                stateDown.currentFont = .smallCaps
                stateDown.smallcaps = true
            } else if node.classes.contains("tl") || node.classes.contains("it") || node.classes.contains("add") {
                stateDown.currentFont = .textFontItalic
            } else if node.classes.contains("qs") || node.classes.contains("qt") {
                stateDown.currentFont = .textFontItalic
            } else {
                if !["yv-v", "verse", "yv-vlbl", "vlbl", "yv-n", "f", "fr", "ft",
                     "qs", "sc", "nd", "cl", "w", "litl", "rq", "x"].contains(c) {
                    assertionFailed("interpretTextAttr: unexpected ", string: c)
                }
            }
        }
    }

    // TODO optimise, if it's worthwhile. Calculate a range and make one new string, not several.
    private static func trimTrailingWhitespaceAndNewlines(_ attributedString: AttributedString) -> AttributedString {
        var localCopy = attributedString
        while let lastCharacter = localCopy.characters.last, lastCharacter.isWhitespace {
            localCopy = AttributedString(localCopy.characters.dropLast())
        }
        return localCopy
    }

    private static func assertionFailed(
        _ message: String,
        string: String? = nil,
        type: BibleTextNodeType? = nil
    ) {
#if false
        // enable this for debugging/tracing this rendering code
        if let type {
            print(message + (string ?? "") + "\(type)")
        } else {
            print(message + (string ?? ""))
        }
#endif
    }

    // input parameters to the rendering; read-only while walking the node structure.
    private struct StateIn {
        var versionId: Int
        var bookUSFM: String
        var currentChapter: Int
        var fromVerse: Int  // in the chapter, the lowest number verse to render. Could be 0.
        var toVerse: Int  // in the chapter, the highest number verse to render. Could be 999.
        var renderVerseNumbers: Bool
        var renderHeadlines: Bool
        var renderFootnotes: Bool
        var footnoteMarker: BibleAttributedString?  // shown when renderFootnotes is true. If nil, they render inline.
        var textColor: Color
        var wocColor: Color
        var fonts: BibleTextFonts
    }

    // As we walk the node structure, these are attributes which
    // child nodes change, but do not pass up to their parent node.
    private struct StateDown {
        var woc = false
        var smallcaps = false
        var alignment = TextAlignment.leading
        var currentFont: BibleTextFontOption
        var textCategory: BibleTextCategory
        var nodeDepth: Int  // for debugging purposes mostly
    }

    // As we walk the node structure, these are attributes which
    // child nodes change and pass up to their parent node.
    private struct StateUp {
        var rendering: Bool
        var firstLineHeadIndent = 0
        var headIndent = 0
        var versionId: Int
        var bookUSFM: String
        var chapter: Int
        var verse: Int
        var text = BibleAttributedString()
        var footnotes: [BibleAttributedString] = []

        mutating func append(_ newText: BibleAttributedString, category: BibleTextCategory) {
            if !newText.isEmpty {
                newText.markWithTextCategory(category)
                if verse > 0 && (category == .scripture || category == .verseLabel) {
                    let reference = BibleReference(versionId: versionId, bookUSFM: bookUSFM, chapter: chapter, verse: verse)
                    newText.markWithReference(reference)
                }
                text += newText
            }
        }

        var endsWithASpace: Bool {
            text.characters.last == " "
        }

        mutating func clearText() {
            text = BibleAttributedString()
        }

        var isTextEmpty: Bool {
            text.isEmpty
        }
    }

}

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

    func markWithReference(_ reference: BibleReference) {
        two.bibleReference = reference
        two.link = URL(string: "reference://\(reference.versionId)/\(reference.asUSFM)")
    }

}

public enum BibleTextCategory: Hashable, Sendable {
    case scripture
    case verseLabel
    case footnoteMarker
    case footnoteText
    case header
}

public enum BibleReferenceAttribute: AttributedStringKey {
    public typealias Value = BibleReference
    public static let name = "BibleReferenceAttribute"
}

public enum BibleTextCategoryAttribute: AttributedStringKey {
    public typealias Value = BibleTextCategory
    public static let name = "BibleTextCategoryAttribute"
}

public struct BibleTextAttributes: AttributeScope {
    let bibleReference: BibleReferenceAttribute
    let bibleTextCategory: BibleTextCategoryAttribute
}

//extension AttributeScopes {
//    var bibleTextAttributes: BibleTextAttributes.Type { BibleTextAttributes.self }
//}

// This extension allows our code to say "myString.bibleReference = ..."
public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<BibleTextAttributes, T>
    ) -> T {
        get { self[T.self] }
    }
}

public struct BibleTextBlock: Identifiable {
    public let id = UUID()
    public let text: BibleAttributedString
    public let chapter: Int
    public let rows: [[BibleAttributedString]]  // If it's a table, these are present instead of "text".
    public let firstLineHeadIndent: Int  // The indentation of the first line of the paragraph. Always >= 0.
    public let headIndent: Int  // The indentation of the paragraph’s lines other than the first. Always >= 0.
    //let tailIndent: Int  // If positive, this value is the distance from the leading margin (for example,
    //the left margin in left-to-right text). If 0 or negative, it’s the distance from the trailing margin.
    public let marginTop: CGFloat
    public let alignment: TextAlignment
    public let footnotes: [BibleAttributedString]

    public init(
        text: BibleAttributedString,
        chapter: Int,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
        alignment: TextAlignment,
        footnotes: [BibleAttributedString],
        rows: [[BibleAttributedString]] = []
    ) {
        self.text = text
        self.chapter = chapter
        self.firstLineHeadIndent = firstLineHeadIndent
        self.headIndent = headIndent
        self.marginTop = marginTop
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
    }

}

#endif
