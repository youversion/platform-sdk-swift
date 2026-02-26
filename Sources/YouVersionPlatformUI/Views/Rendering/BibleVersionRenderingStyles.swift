#if canImport(SwiftUI)
import SwiftUI
import YouVersionPlatformCore

@MainActor
final class BibleVersionRenderingStyles {

    static func interpretBlockClasses(
        _ classes: [String],
        stateIn: BibleVersionRendering.StateIn,
        stateDown: inout BibleVersionRendering.StateDown,
        stateUp: inout BibleVersionRendering.StateUp,
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
                    BibleVersionRendering.assertionFailed("interpreting block classes: unexpected ", string: c)
                }
            }
        }
    }

    static func interpretTextAttr(
        _ node: BibleTextNode,
        stateIn: BibleVersionRendering.StateIn,
        stateDown: inout BibleVersionRendering.StateDown,
        stateUp: inout BibleVersionRendering.StateUp
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
                    BibleVersionRendering.assertionFailed("interpretTextAttr: unexpected ", string: c)
                }
            }
        }
    }
}

#endif
