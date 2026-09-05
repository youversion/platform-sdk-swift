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
        let fontSize = stateIn.fonts.baseSize

        for c in classes {
            switch c {
                
            case "cl":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500
                stateDown.marginBottom = 0.25 * fontSize
                stateDown.marginTop = 0

            case "cls":
                stateDown.alignment = .trailing

            case "d":
                stateDown.alignment = .center
                stateDown.currentFont = .font100emItalic
                stateDown.marginTop = 0.60 * fontSize
                stateDown.marginBottom = 1.20 * fontSize
                stateDown.textCategory = .header

            case "iex":
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 0

            case "imq":
                stateDown.currentFont = .font100emItalic
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "imt":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500
                stateDown.textCategory = .header

            case "imt1":
                stateDown.textCategory = .header
                stateDown.currentFont = .font117em500
                stateDown.alignment = .center
                stateDown.marginTop = 0.50 * fontSize
                stateDown.marginBottom = 0.25 * fontSize

            case "imt2":
                stateDown.textCategory = .header
                stateDown.currentFont = .font100emItalic
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2
                stateDown.marginBottom = 0.25 * fontSize

            case "imt3":
                stateDown.textCategory = .header
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = 0.125 * fontSize
                stateDown.marginBottom = 0.125 * fontSize

            case "ior":
                break

            case "is":
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2

            case "is1":
                stateDown.currentFont = .font117em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2
                stateDown.marginBottom = 0.25 * fontSize

            case "lh":
                stateUp.firstLineHeadIndent = 1

            case "li":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

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

            case "lim":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "m", "im":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "mi":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "mr":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500Italic
                stateDown.marginBottom = 0.60 * fontSize
                stateDown.marginTop = 0

            case "ms":
                stateDown.alignment = .center
                stateDown.currentFont = .font100em500
                stateDown.marginBottom = 0.60 * fontSize
                stateDown.marginTop = 0

            case "ms1":
                stateDown.alignment = .center
                stateDown.currentFont = .font117em500
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize

            case "ms2", "ms3", "ms4":
                stateDown.alignment = .center
                stateDown.currentFont = .font100em500
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize

            case "mt1":
                stateDown.textCategory = .header
                stateDown.currentFont = .font117em500
                stateDown.alignment = .center
                stateDown.marginTop = 0.25 * fontSize
                stateDown.marginBottom = 0.50 * fontSize

            case "mt2":
                stateDown.textCategory = .header
                stateDown.currentFont = .font117em500Italic
                stateDown.alignment = .center
                stateDown.marginBottom = 0.25 * fontSize

            case "nb":
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "p", "ip":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 0

            case "pc":
                stateDown.alignment = .center
                stateDown.marginBottom = 0.60 * fontSize
                stateDown.smallcaps = true
                stateDown.textCategory = .header

            case "pi":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "pi1", "ipi":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 2

            case "pi2":
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 4

            case "pi3":
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 6

            case "pm", "pmc", "pmo":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 2

            case "pmr":
                stateDown.alignment = .trailing
                stateDown.marginBottom = 0.50 * fontSize

            case "po":
                stateDown.marginTop = 0.25 * fontSize
                stateDown.marginBottom = 0.25 * fontSize
                stateUp.firstLineHeadIndent = 1

            case "q", "q1", "iq", "iq1":
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
                stateUp.headIndent = 8

            case "qa":
                stateDown.currentFont = .font117em500Italic
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateDown.textCategory = .header
                stateUp.headIndent = 0

            case "qc":
                stateDown.alignment = .center
                stateDown.marginBottom = 0
                stateDown.marginTop = 0

            case "qm":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
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

            case "qm3":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 6

            case "qm4":
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 8

            case "qr":
                stateDown.alignment = .trailing
                stateDown.currentFont = .font100emItalic

            case "r":
                stateDown.currentFont = .font100emItalic
                stateDown.alignment = .center
                stateDown.marginTop = 0
                stateDown.marginBottom = 0.25 * fontSize

            case "s":
                stateDown.marginTop = 0
                stateDown.marginBottom = 0.25 * fontSize
                stateDown.currentFont = .font117em500
                stateUp.headIndent = 0
                stateUp.firstLineHeadIndent = 0

            case "s1":
                stateDown.marginTop = 0
                stateDown.marginBottom = 0.25 * fontSize
                stateDown.currentFont = .font117em500
                stateUp.headIndent = 0
                stateUp.firstLineHeadIndent = 0

            case "s2", "s3", "s4":
                stateDown.marginTop = 0.5 * fontSize
                stateDown.marginBottom = 0.5 * fontSize
                stateDown.currentFont = .font100em500Italic
                stateUp.headIndent = 0
                stateUp.firstLineHeadIndent = 0

            case "sp":
                stateDown.currentFont = .font117em500Italic
                stateDown.marginBottom = 0.50 * fontSize
                stateDown.marginTop = 0.50 * fontSize
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0

            case "sr":
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginBottom = 0.25 * fontSize

            case "yv-h", "yvh":
                stateUp.firstLineHeadIndent = 0
                stateDown.textCategory = .header
                if !stateIn.renderHeadlines {
                    stateUp.rendering = false
                }

            // The tags below here are not yet adjusted for our new
            // typography standards; they may or may not reflect the new way.
            case "imi":
                stateDown.marginBottom = 0.60 * fontSize
                stateUp.firstLineHeadIndent = 1
                stateUp.headIndent = 0

            case "pr":
                stateDown.alignment = .trailing

            case "iot":
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3

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

            case "imte", "imte1":
                stateDown.textCategory = .header
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center

            case "imte2":
                stateDown.textCategory = .header
                stateDown.currentFont = .font100emItalic
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 2
                stateDown.marginBottom = 0.25 * fontSize

            case "imt4":
                stateDown.textCategory = .header
                stateDown.currentFont = .font100em500
                stateDown.alignment = .center
                stateDown.marginTop = fontSize / 3

            case "b", "lf":
                break

            default:
                BibleVersionRendering.assertionFailed("interpretBlockClasses: unexpected class: \(c)")
            }
            if stateDown.alignment == .center {
                stateUp.firstLineHeadIndent = 0
                stateUp.headIndent = 0
            }
        }
    }

    static func interpretTextAttr(
        _ node: BibleTextNode,
        stateIn: BibleVersionRendering.StateIn,
        stateDown: inout BibleVersionRendering.StateDown,
        stateUp: inout BibleVersionRendering.StateUp
    ) {
        for c in node.classes {
            switch c {

            case "wj":
                stateDown.woc = true

            case "yv-v", "verse":  // (invisible) start of a verse.
                if let v = node.attributes["v"] {
                    if let vi = Int(v) {
                        stateUp.verse = vi
                        stateUp.rendering = (vi >= stateIn.fromVerse) && (vi <= stateIn.toVerse)
                    }
                }

            case "nd", "sc":
                stateDown.smallcaps = true

            case "rq":
                stateDown.currentFont = .font083emItalic

            case "tl", "it", "add", "em", "fq", "fqa", "qac", "qs", "qt", "bk", "sig", "litl":
                stateDown.currentFont = .font100emItalic

            case "bd", "pn":
                stateDown.currentFont = .font100em500

            case "bdit", "fk", "fl":
                stateDown.currentFont = .font100em500Italic
            
            case "ord", "fv", "sup", "va":
                stateDown.currentFont = .verseNumFont  // superscript, really; same thing in practice.
                stateDown.baselineOffset = stateIn.fonts.verseNumBaselineOffset

            default:
                if !["yv-v", "verse", "yv-vlbl", "vlbl", "yv-n", "f", "fp", "fr", "ft",
                     "w", "ior", "ref", "wg", "wh", "x", "xta"].contains(c) {
                    BibleVersionRendering.assertionFailed("interpretTextAttr: unexpected ", string: c)
                }
            }
        }
        if node.classes.contains("fp") && stateDown.textCategory == .footnoteText && !stateUp.isTextEmpty {
            let paragraphBreak = BibleAttributedString("\n")
            paragraphBreak.setFont(stateDown.currentFont, from: stateIn.fonts)
            stateUp.append(paragraphBreak, category: .footnoteText)
        }
    }
}

#endif
