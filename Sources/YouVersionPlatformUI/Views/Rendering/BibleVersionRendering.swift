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
                reference: reference,
                renderHeadlines: false,
                renderVerseNumbers: false,
                footnotesMode: .none,
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
    public static func textBlocks(
        from textNode: BibleTextNode? = nil,
        reference: BibleReference,
        renderHeadlines: Bool = true,
        renderVerseNumbers: Bool = true,
        footnotesMode: BibleTextFootnoteMode = .letters,
        footnoteMarker: BibleAttributedString? = nil,
        textColor: Color = Color.primary,
        wocColor: Color = Color.red,
        fonts: BibleTextFonts
    ) async throws -> [BibleTextBlock]? {
        var node = textNode
        if node == nil {
            node = try await rootNode(from: reference)
        }
        guard let node, !node.children.isEmpty else {
            return nil
        }
        return generateTextBlocks(
            from: node,
            reference: reference,
            renderHeadlines: renderHeadlines,
            renderVerseNumbers: renderVerseNumbers,
            footnotesMode: footnotesMode,
            footnoteMarker: footnoteMarker,
            textColor: textColor,
            wocColor: wocColor,
            fonts: fonts
        )
    }

    static func generateTextBlocks(
        from node: BibleTextNode,
        reference: BibleReference,
        renderHeadlines: Bool,
        renderVerseNumbers: Bool,
        footnotesMode: BibleTextFootnoteMode,
        footnoteMarker: BibleAttributedString?,
        textColor: Color,
        wocColor: Color,
        fonts: BibleTextFonts
    ) -> [BibleTextBlock] {
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
            footnotesMode: footnotesMode,
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
            baselineOffset: 0,
            textCategory: .scripture,
            nodeDepth: 0
        )
        var stateUp = StateUp(
            rendering: verseStart <= 1,
            firstLineHeadIndent: 0,
            headIndent: 0,
            versionId: reference.versionId,
            bookUSFM: reference.bookUSFM,
            chapter: reference.chapter,
            verse: 0
        )

        if let firstChild = node.children.first {
            handleNodeBlock(
                node: firstChild,
                stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp,
                ret: &ret
            )
        }
        return ret
    }

    /// Fetches the data for the given reference, returns it converted to a BibleTextNode tree.
    static func rootNode(from reference: BibleReference) async throws -> BibleTextNode? {
        let book = reference.bookUSFM
        let c = reference.chapter
        let chapterReference = BibleReference(versionId: reference.versionId, bookUSFM: book, chapter: c)

        do {
            let data = try await BibleChapterRepository.shared.chapter(withReference: chapterReference)
            var node = try? BibleTextNode.parse(data)
            if node?.children.count ?? 0 == 0 {
                // cached chapter data seems bad. Remove the cached data and retry.
                await BibleChapterRepository.shared.removeVersion(withId: reference.versionId)
                let data = try await BibleChapterRepository.shared.chapter(withReference: chapterReference)
                node = try? BibleTextNode.parse(data)
            }
            return node
        } catch YouVersionAPIError.notPermitted {
            throw YouVersionAPIError.notPermitted
        } catch {
            return nil
        }
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
            if stateDown.baselineOffset != 0 {
                txt.setBaselineOffset(stateDown.baselineOffset)
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
            if stateUp.rendering && stateIn.footnotesMode != .none {
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

        var marker: BibleAttributedString?
        switch stateIn.footnotesMode {
        case .image:
            marker = BibleAttributedString("💬")  // for spacing purposes; won't be rendered.
                .setFont(.footnote, from: stateIn.fonts)
        case .letters:
            marker = stateUp.nextFootnoteMarker
                .setFont(.footnote, from: stateIn.fonts)
                .setColor(stateIn.textColor.opacity(stateIn.fonts.verseNumOpacity))
                .setBaselineOffset(stateIn.fonts.verseNumBaselineOffset)
        default:
            marker = stateIn.footnoteMarker
        }

        if let marker {
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
            let footnote = stateUp.appendFootnote(text: footState.text)
            stateUp.append(marker, category: stateIn.footnotesMode == .image ? .footnoteImage : .footnoteMarker, id: footnote.id)
        } else {
            for child in node.children {
                stateDown.currentFont = .footnote
                handleBlockChild(child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp)
            }
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

        if node.type != .block {
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

        for (index, child) in node.children.enumerated() {
            if child.type == .block || child.type == .table {
                let hadPendingText = !stateUp.isTextEmpty
                if hadPendingText {
                    if stateUp.rendering {
                        ret.append(createBlock(stateDown: stateDown, stateUp: &stateUp, marginTop: marginTop))
                    }
                    stateUp.clearText()
                }
                let isHeader = child.classes.contains("yv-h") || child.classes.contains("yvh")
                let savedRendering = stateUp.rendering

                if isHeader && stateIn.renderHeadlines {
                    let followingChildren = node.children.dropFirst(index + 1)
                    let nextVerse = followingChildren
                        .compactMap { firstVerseInNode($0) }
                        .first
                    let immediateNextVerse = followingChildren.first.flatMap { firstVerseInNode($0) }
                    let isNextVerseInRange = nextVerse != nil
                        && nextVerse! >= stateIn.fromVerse
                        && nextVerse! <= stateIn.toVerse

                    if !stateUp.rendering && isNextVerseInRange {
                        stateUp.rendering = true
                    } else if stateUp.rendering && nextVerse != nil && !isNextVerseInRange && !hadPendingText && immediateNextVerse != nil {
                        stateUp.rendering = false
                    }
                }

                if child.type == .block {
                    handleNodeBlock(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp, ret: &ret)
                } else if child.type == .table {
                    handleNodeTable(node: child, stateIn: stateIn, stateDown: stateDown, stateUp: &stateUp, ret: &ret)
                }

                if isHeader {
                    stateUp.rendering = savedRendering
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
            "lf",  // List footer (introductory remark)
            "mr", "ms", "ms1", "ms2", "ms3", "ms4", "s2", "s3", "s4", "sp",  // handled inside yv-h
            "iex", // see John 7:52
            "ms1",
            "qa",
            "r",
            "sr",
            "po",
            "im",  // non-indented intro paragraph
            "ior"  // marks references in an outline
        ]

        for c in classes {
            switch c {

            case "p", "ip", "imi", "ipi":
                stateUp.firstLineHeadIndent = indentStep * 2
                stateUp.headIndent = 0

            case "m", "nb", "im":
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
                stateUp.firstLineHeadIndent = indentStep
                stateUp.headIndent = indentStep * 2

            case "pi3":
                stateUp.firstLineHeadIndent = indentStep
                stateUp.headIndent = indentStep * 3

            case "li1", "ili", "ili1":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = indentStep

            case "li2", "ili2":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = indentStep * 2

            case "li3", "ili3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = indentStep * 3

            case "li4", "ili4":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = indentStep * 4

            case "iq", "iq1", "q", "q1", "qm", "qm1":
                // Sadly SwiftUI cannot do this yet, but we want (0, 2 * indentStep) here.
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq2", "q2", "qm2":
                // Sadly SwiftUI cannot do this yet, but we want (indentStep, 2 * indentStep) here.
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq3", "q3", "qm3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iq4", "q4", "qm4":
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
            
            case "iot":
                stateDown.currentFont = .textFontBold
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 3
            
            case "is", "is1":
                stateDown.currentFont = .header2  // want bold and a little larger than body
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 2
            
            case "is2":
                stateDown.currentFont = .textFontBold
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 3
            
            case "io", "io1":
                stateUp.headIndent = indentStep * 2
                
            case "io2":
                stateUp.headIndent = indentStep * 3
                
            case "io3", "io4":
                stateUp.headIndent = indentStep * 4
                
            case "imt", "imt1", "imte", "imte1":
                stateDown.textCategory = .header
                stateDown.currentFont = .header
                stateDown.alignment = .center

            case "imt2", "imte2":
                stateDown.textCategory = .header
                stateDown.currentFont = .headerItalic
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 2

            case "imt3":
                stateDown.textCategory = .header
                stateDown.currentFont = .header3
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 3

            case "imt4":
                stateDown.textCategory = .header
                stateDown.currentFont = .header4
                stateDown.alignment = .center
                marginTop = stateIn.fonts.baseSize / 3
                
            case "yv-h", "yvh":  // yv-h meaning header
                let fontMap: [String: BibleTextFontOption] = [
                    "s1": .headerItalic,
                    "imt": .header,
                    "imt1": .header,
                    "ms": .header2,
                    "ms1": .header2,
                    "s2": .header2,
                    "ms2": .header2,
                    "imt2": .header2,
                    "s3": .header3,
                    "ms3": .header3,
                    "imt3": .header3,
                    "s4": .header4,
                    "ms4": .header4,
                    "imt4": .header4,
                    "sp": .headerItalic,
                    "r": .headerItalic,
                    "sr": .headerItalic,
                    "mr": .headerSmaller
                ]
                marginTop = stateIn.fonts.baseSize
                stateDown.textCategory = .header
                stateDown.currentFont = .header
                for c in classes {
                    if let font = fontMap[c] {
                        stateDown.currentFont = font
                    }
                }
                if classes.contains("mr") {
                    marginTop = 0
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
            } else if node.classes.contains("fq") || node.classes.contains("fqa") || node.classes.contains("add") {
                stateDown.currentFont = .textFontItalic
            } else if node.classes.contains("qs") || node.classes.contains("qt") {
                stateDown.currentFont = .textFontItalic
            } else if node.classes.contains("ord") || node.classes.contains("fv") || node.classes.contains("sup") {
                stateDown.currentFont = .verseNumFont  // superscript, really; same thing in practice.
                stateDown.baselineOffset = stateIn.fonts.verseNumBaselineOffset
            } else {
                if !["yv-v", "verse", "yv-vlbl", "vlbl", "yv-n", "f", "fr", "ft",
                     "qs", "sc", "nd", "cl", "w", "litl", "rq", "x"].contains(c) {
                    assertionFailed("interpretTextAttr: unexpected ", string: c)
                }
            }
        }
    }

    private static func trimTrailingWhitespaceAndNewlines(_ attributedString: AttributedString) -> AttributedString {
        var localCopy = attributedString
        while let lastCharacter = localCopy.characters.last, lastCharacter.isWhitespace {
            localCopy = AttributedString(localCopy.characters.dropLast())
        }
        return localCopy
    }

    /// Finds the first verse number in a node's subtree by searching for verse-labeled spans.
    private static func firstVerseInNode(_ node: BibleTextNode) -> Int? {
        if node.classes.contains("yv-v") || node.classes.contains("verse") {
            if let v = node.attributes["v"], let vi = Int(v) {
                return vi
            }
        }
        for child in node.children {
            if let found = firstVerseInNode(child) {
                return found
            }
        }
        return nil
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
        var footnotesMode: BibleTextFootnoteMode
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
        var baselineOffset: CGFloat = 0
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
        var footnotes: [BibleFootnote] = []
        var footnoteCounter = 100

        var nextFootnoteMarker: BibleAttributedString {
            // First footnote -> "a", second -> "b", etc.
            let value = UnicodeScalar("a").value + UInt32(min(25, footnotes.count))
            return BibleAttributedString("\u{00a0}" + (String(UnicodeScalar(value) ?? "※") + " "))
        }

        mutating func append(_ newText: BibleAttributedString, category: BibleTextCategory, id: String? = nil) {
            if !newText.isEmpty {
                newText.markWithTextCategory(category)
                let isFootnote = category == .footnoteMarker || category == .footnoteImage
                if isFootnote || (verse > 0 && (category == .scripture || category == .verseLabel)) {
                    let reference = BibleReference(versionId: versionId, bookUSFM: bookUSFM, chapter: chapter, verse: verse > 0 ? verse : 1)
                    let scheme = isFootnote ? BibleVersionRendering.LinkSchemes.footnote.rawValue : BibleVersionRendering.LinkSchemes.reference.rawValue
                    newText.markWithReference(reference, scheme: scheme, id: id)
                }
                text += newText
            }
        }

        mutating func appendFootnote(text: BibleAttributedString) -> BibleFootnote {
            let reference = BibleReference(
                versionId: versionId,
                bookUSFM: bookUSFM,
                chapter: chapter,
                verse: verse > 0 ? verse : 1
            )
            footnoteCounter += 1
            let footnote = BibleFootnote(text: text, reference: reference, id: String(footnoteCounter))
            footnotes.append(footnote)
            return footnote
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

    public enum LinkSchemes: String {
        case footnote
        case reference
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

    func markWithReference(_ reference: BibleReference, scheme: String, id: String?) {
        two.bibleReference = reference
        let idString = id == nil ? "" : "#\(id!)"
        two.link = URL(string: "\(scheme)://\(reference.versionId)/\(reference.asUSFM)\(idString)")
    }

}

public enum BibleTextCategory: Hashable, Sendable {
    case scripture
    case verseLabel
    case footnoteMarker
    case footnoteImage
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
// Represents a footnote and its reference location.
public struct BibleFootnote: Hashable, Identifiable {
    public let id: String
    public let text: BibleAttributedString
    public let reference: BibleReference

    public init(text: BibleAttributedString, reference: BibleReference, id: String) {
        self.text = text
        self.reference = reference
        self.id = id
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
    public let footnotes: [BibleFootnote]

    public init(
        text: BibleAttributedString,
        chapter: Int,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
        alignment: TextAlignment,
        footnotes: [BibleFootnote],
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

public enum BibleTextFootnoteMode {
    case none
    case inline
    case marker
    case letters  // "a", "b", etc. within the passage
    case image
}

#endif
