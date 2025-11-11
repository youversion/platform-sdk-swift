import SwiftUI
import YouVersionPlatformCore

extension BibleTextView {
    @ViewBuilder
    func view(for block: BibleTextBlock, textOptions: BibleTextOptions, ignoreMarginTop: Bool) -> some View {
        if block.rows.isEmpty {
            let theView = emitTextBlock(block, textOptions: textOptions, ignoreMarginTop: ignoreMarginTop)
            if block.alignment == .leading {
                theView
            } else {
                HStack {
                    Spacer()
                    theView
                    if block.alignment == .center {
                        Spacer()
                    }
                }
            }
        } else {
            emitTableRows(block.rows, textOptions: textOptions)
        }
    }

    // This hack is necessary because AttributedString doesn't have a
    // ParagraphStyle or any other way to specify .firstLineHeadIndent.
    // NSAttributedString has paragraphStyle.firstLineHeadIndent which would be ideal.
    private func indentString(_ indent: Int) -> AttributedString {
        let nbsp = "\u{00a0}\u{00a0}"
        return AttributedString(String(repeating: nbsp, count: min(max(indent, 0), 4)))
    }

    // Custom text renderer which implements the custom way we want to underline
    // the selected verses.
    // Also, by using this TextRenderer we work around a SwiftUI bug in how
    // SwiftUI draws background colors for our verse numbers. Without having
    // this active, the area painted in the background color sometimes shifts
    // upwards according to the baseline offset. And/or partially shifts.
    struct BibleRenderer: TextRenderer {
        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            for line in layout {
                let lineRect = line.typographicBounds.rect
                for run in line {
                    let attrs = run[RenderHowAttribute.self]
                    if attrs?.underlined == true {
                        let runRect = run.typographicBounds.rect
                        let yPosition = lineRect.origin.y + line.typographicBounds.ascent + line.typographicBounds.descent + 2
                        let start = CGPoint(x: runRect.origin.x, y: yPosition)
                        let end   = CGPoint(x: runRect.origin.x + runRect.size.width, y: yPosition)
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(.gray), lineWidth: 0.5)
                    }
                }
                context.draw(line)
            }
        }
    }

    struct RenderHowAttribute: TextAttribute {
        var underlined: Bool
    }

    private func textViewFor(double: BibleAttributedString, firstLineHeadIndent: Int, blockId: UUID, textOptions: BibleTextOptions) -> some View {
        let string = double.asAttributedString
        // Copy the category from AttributedString-world into Text-world.
        // textCombo is a Text object built up from multiple Text objects,
        // each with its own customAttribute value for how to render.
        let indent = indentString(firstLineHeadIndent)
        var textCombo = Text(indent)
        let runs = string.runs[\.bibleTextCategory, \.bibleReference]
        for run in runs {
            let category = run.0 // as? BibleTextCategory
            let reference: BibleReference? = run.1 // as? BibleReference
            let range = run.2
            var t = AttributedString(string[range])
            if category == .scripture {
                t.backgroundColor = highlightFor(reference: reference)
                // better, we could have our TextRenderer add the color to some portions
            }
            let isUnderlined = isSelected(reference) && category == .scripture
            // swiftlint:disable:next shorthand_operator
            textCombo = textCombo + Text(t).customAttribute(RenderHowAttribute(underlined: isUnderlined))
        }

        let retValue = textCombo
            .tint(textOptions.textColor ?? .primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, textOptions.paragraphSpacing)
            .if(textOptions.lineSpacing != nil) { view in
                view.lineSpacing(textOptions.lineSpacing!)
            }
        if #available(iOS 18.0, *) {
            return retValue.textRenderer(BibleRenderer())
        } else {
            return retValue  // TODO: must we support earlier iOS versions? Use the generic underline, maybe?
        }
    }

    private func emitTextBlock(_ block: BibleTextBlock, textOptions: BibleTextOptions, ignoreMarginTop: Bool) -> some View {
        textViewFor(
            double: block.text,
            firstLineHeadIndent: block.firstLineHeadIndent,
            blockId: block.id,
            textOptions: textOptions
        )
        .multilineTextAlignment(flipAlignmentIfNecessary(block.alignment))
        .padding(.leading, CGFloat(8 * block.headIndent))
        .padding(.top, ignoreMarginTop ? 0 : block.marginTop)
    }

    private func emitTableRows(_ doubleRows: [[BibleAttributedString]], textOptions: BibleTextOptions) -> some View {
        // First, make sure each row has the same number of cells
        let numCols = doubleRows.map({ $0.count }).max() ?? 0
        let theRows = doubleRows.map { cells in
            var modCells = cells  // copy so we can change it
            while modCells.count < numCols {
                modCells.append(BibleAttributedString())
            }
            return TableRowDoubleStrings(doubles: modCells.map { str in TableCellDoubleString(double: str) })
        }

        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 15, verticalSpacing: 10) {
            ForEach(theRows, id: \.self) { row in
                GridRow {
                    ForEach(row.doubles, id: \.self) { cell in
                        textViewFor(
                            double: cell.double,
                            firstLineHeadIndent: 0,
                            blockId: cell.id,
                            textOptions: textOptions
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .gridColumnAlignment(.leading)
                    }
                }
            }
        }
        .padding()
    }

    private func isSelected(_ reference: BibleReference?) -> Bool {
        guard let reference else {
            return false
        }
        for verse in selectedVerses {
            if verse.chapter == reference.chapter && verse.verseStart == reference.verseStart {
                return true
            }
        }
        return false
    }

    private func highlightFor(reference: BibleReference?) -> Color {
        guard let reference else {
            return .clear
        }
        for highlight in ourHighlights {
            if highlight.reference.chapter == reference.chapter && highlight.reference.verseStart == reference.verseStart {
                return Color(hex: highlight.color)
            }
        }
        return .clear
    }

    // so that the Grid has a Hashable, Identifiable list to work with
    private struct TableCellDoubleString: Hashable, Identifiable {
        let id = UUID()  // for Identifiable
        let double: BibleAttributedString
    }

    private struct TableRowDoubleStrings: Hashable, Identifiable {
        let id = UUID()  // for Identifiable
        let doubles: [TableCellDoubleString]
    }

}
