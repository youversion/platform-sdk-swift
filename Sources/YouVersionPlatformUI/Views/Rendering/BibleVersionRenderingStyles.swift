#if canImport(SwiftUI)
import SwiftUI
import YouVersionPlatformCore

@MainActor
final class BibleVersionRenderingStyles {

    static func interpretBlockClasses(
        _ classes: [String],
        stateIn: BibleVersionRendering.StateIn,
        stateDown: inout BibleVersionRendering.StateDown,
        stateUp: inout BibleVersionRendering.StateUp
    ) {
        let ignoredTags = [  // things we don't currently care about:
            "b",   // Poetry text stanza break (e.g. stanza break)
            "lh",  // A list header (introductory remark)
            "li",  // A list entry, level 1 (if single level)
            "lf",  // List footer (introductory remark)
            "ms1", "ms2", "ms3", "ms4", "s3", "s4", "sp",  // handled inside yv-h
            "iex", // see John 7:52
            "sr",
            "po",
            "ior"  // marks references in an outline
        ]
        let fontSize = stateIn.fonts.baseSize

        for c in classes {
            switch c {
                
            case "cl":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500
                stateDown.marginBottom = 0.25 * fontSize
                stateDown.marginTop = 0
                
            case "d":
                stateDown.alignment = .center
                stateDown.currentFont = .font100emItalic
                stateDown.marginTop = 0.60 * fontSize
                stateDown.marginBottom = 1.20 * fontSize
                stateDown.textCategory = .header

            case "imt":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500
                stateDown.textCategory = .header

            case "li1", "ili", "ili1":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "li2", "ili2":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 4

            case "li3", "ili3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 6

            case "li4", "ili4":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 8

            case "m", "im":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0
                
            case "mi":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "p", "ip":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 0
                
            case "pc":
                stateDown.alignment = .center
                stateDown.marginBottom = 0.60 * fontSize
                stateDown.smallcaps = true
                stateDown.textCategory = .header

            case "pi", "pi1", "ipi":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 2

            case "pi2":
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 4

            case "pi3":
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 6

            case "pm":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "pmo":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "qa":
                stateDown.currentFont = .font117em500Italic
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateDown.textCategory = .header
                stateUp.headIndent = 0

            case "qm1":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "qm2":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 4

            case "qr":
                stateDown.alignment = .trailing
                stateDown.currentFont = .font100emItalic

            case "q1", "iq1":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2
                
            case "q2", "iq2":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 4
                
            case "q3", "iq3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 6

            case "q4", "iq4":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 6

            case "s1":
                stateDown.marginTop = 0
                stateDown.marginBottom = 0.25 * fontSize
                stateDown.currentFont = .font117em500
                stateUp.headIndent = 0
                
            case "s2":
                stateDown.marginTop = 0.5 * fontSize
                stateDown.marginBottom = 0.5 * fontSize
                stateDown.currentFont = .font100em500Italic
                stateUp.headIndent = 0

            // The tags below here are not yet adjusted for our new
            // typography standards; they may or may not reflect the new way.
            case "imi":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 0
                
            case "pmc", "pmr":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 4
                stateDown.marginBottom = 0.60 * fontSize

            case "nb":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0
                
            case "ms", "mr":
                stateDown.alignment = .center
                stateDown.marginBottom = 0.60 * fontSize
                stateDown.marginTop = 0 - (fontSize * 0.75)  // bug: should be a % of lineSpacing but we don't have that here yet

            case "pr":
                stateDown.alignment = .trailing

            case "qc":
                stateDown.alignment = .center
                stateDown.smallcaps = true
                stateDown.textCategory = .header

            case "iq", "q", "qm":
                // Sadly SwiftUI cannot do this yet, but we want (0, 2) here.
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "qm3":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "qm4":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "iot":
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3

            case "is", "is1":
                stateDown.currentFont = .header
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2

            case "is2":
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3

            case "io", "io1":
                stateUp.headIndent = 2

            case "io2":
                stateUp.headIndent = 3

            case "io3", "io4":
                stateUp.headIndent = 4

            case "imt1", "imte", "imte1":
                stateDown.textCategory = .header
                stateDown.currentFont = .header
                stateDown.alignment = .center

            case "imt2", "imte2":
                stateDown.textCategory = .header
                stateDown.currentFont = .headerItalic
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2

            case "imt3":
                stateDown.textCategory = .header
                stateDown.currentFont = .header3
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3

            case "imt4":
                stateDown.textCategory = .header
                stateDown.currentFont = .header4
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3
            
            case "r":
                stateDown.currentFont = .headerSmallerItalic
                stateDown.marginTop = 0 - (fontSize * 0.75)  // bug: should be a % of lineSpacing but we don't have that here yet

            case "yv-h", "yvh":  // yv-h meaning header
                let fontsByClass: [String: BibleTextFontOption] = [
                    "imt1": .header,
                    "ms": .font117em500,
                    "mr": .font117em500Italic,
                    "cl": .font117em500,
                    "ms1": .header2,
                    "ms2": .header2,
                    "imt2": .header2,
                    "s3": .header3,
                    "ms3": .header3,
                    "imt3": .header3,
                    "s4": .header4,
                    "ms4": .header4,
                    "imt4": .header4,
                    "sp": .headerItalic,
                    "sr": .headerItalic
                ]
                for c in classes {
                    if let font = fontsByClass[c] {
                        stateDown.currentFont = font
                    }
                }
                stateUp.firstLineHeadIndent = 0
                stateDown.textCategory = .header
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
                stateDown.currentFont = .font100emItalic
            } else if node.classes.contains("fq") || node.classes.contains("fqa") || node.classes.contains("add") {
                stateDown.currentFont = .font100emItalic
            } else if node.classes.contains("qs") || node.classes.contains("qt") {
                stateDown.currentFont = .font100emItalic
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
