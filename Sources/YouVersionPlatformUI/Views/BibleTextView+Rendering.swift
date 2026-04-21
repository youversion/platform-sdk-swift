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
        let footnoteIcon: Image
        let noteIndicatorIcon: Image
        let verseSelectionStyle: VerseSelectionStyle

        init(verseSelectionStyle: VerseSelectionStyle = .solid) {
            footnoteIcon = Image("footnoteIcon", bundle: .YouVersionUIBundle)
            noteIndicatorIcon = Image("noteIndicatorIcon", bundle: .YouVersionUIBundle)
            self.verseSelectionStyle = verseSelectionStyle
        }

        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            let footnoteImage = context.resolve(footnoteIcon)
            let noteIndicatorImage = context.resolve(noteIndicatorIcon)

            for line in layout {
                let lineRect = line.typographicBounds.rect

                // Pass 1: draw note-indicator box backgrounds
                var boxStart: CGFloat?
                var boxEnd: CGFloat = 0
                var boxY: CGFloat = 0
                var boxHeight: CGFloat = 0
                var boxColor: Color?

                func flushBox(in context: inout GraphicsContext) {
                    guard let start = boxStart else {
                        return
                    }
                    let padding: CGFloat = 2
                    let boxRect = CGRect(x: start - padding,
                                         y: boxY,
                                         width: (boxEnd - start) + padding * 2,
                                         height: boxHeight)
                    let path = RoundedRectangle(cornerRadius: 2).path(in: boxRect)
                    context.fill(path, with: .color(boxColor ?? .gray))
                    boxStart = nil
                }

                for run in line {
                    let attrs = run[RenderHowAttribute.self]
                    if attrs?.noteIndicatorBox == true {
                        let rect = run.typographicBounds.rect
                        if boxStart == nil {
                            boxStart = rect.minX
                            boxY = rect.minY
                            boxHeight = rect.height
                            boxColor = attrs?.noteIndicatorBoxColor
                        }
                        boxEnd = rect.maxX
                        boxHeight = max(boxHeight, rect.height)
                    } else if boxStart != nil {
                        flushBox(in: &context)
                    }
                }
                flushBox(in: &context)

                // Pass 2: draw text runs and custom images
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
                        let underlineColor = attrs?.underlineColor ?? verseSelectionStyle.color
                        context.stroke(
                            path,
                            with: .color(underlineColor),
                            style: verseSelectionStyle.strokeStyle
                        )
                    }
                    if attrs?.noteIndicatorImage == true {
                        let runRect = run.typographicBounds.rect
                        let size = runRect.height * 0.75
                        let rect = CGRect(
                            x: runRect.origin.x,
                            y: runRect.origin.y + (runRect.height - size) / 2,
                            width: size,
                            height: size
                        )
                        context.draw(noteIndicatorImage, in: rect)
                    } else if attrs?.footnoteImage == true {
                        let runRect = run.typographicBounds.rect
                        let height = runRect.height
                        let rect = CGRect(
                            x: runRect.origin.x,
                            y: runRect.origin.y - (height / 4),
                            width: height,
                            height: height
                        )
                        context.draw(footnoteImage, in: rect)
                    } else {
                        context.draw(run)
                    }
                }
            }
        }
    }

    struct RenderHowAttribute: TextAttribute {
        var underlined = false
        var underlineColor: Color?
        var footnoteImage = false
        var noteIndicatorImage = false
        var noteIndicatorBox = false
        var noteIndicatorBoxColor: Color?
    }

    private func textViewFor(double: BibleAttributedString, firstLineHeadIndent: Int, blockId: UUID, textOptions: BibleTextOptions) -> some View {
        let string = double.asAttributedString
        // Copy the category from AttributedString-world into Text-world.
        // textCombo is a Text object built up from multiple Text objects,
        // each with its own customAttribute value for how to render.
        var textCombo = Text(indentString(firstLineHeadIndent))
        let runs = string.runs[\.bibleTextCategory, \.bibleReference]
        for run in runs {
            let category = run.0 // as? BibleTextCategory
            let reference: BibleReference? = run.1 // as? BibleReference
            let range = run.2
            var t = AttributedString(string[range])
            if category == .scripture || category == .verseLabel {
                t.backgroundColor = highlightFor(reference: reference)
                // better, we could have our TextRenderer add the color to some portions
            }
            if category == .verseLabel, let reference,
               noteIndicatedUSFMs.contains(reference.asUSFM) {
                let hasHighlight = highlightFor(reference: reference) != .clear
                let boxColor = hasHighlight
                    ? textOptions.noteIndicatorBoxHighlightColor
                    : textOptions.noteIndicatorBoxColor

                let noteURL = URL(string: "\(BibleVersionRendering.LinkSchemes.noteIndicator.rawValue)://\(reference.versionId)/\(reference.asUSFM)")

                var pencilAttr = AttributedString("\u{FFFC}")
                pencilAttr.link = noteURL
                pencilAttr.foregroundColor = textOptions.verseNumColor ?? .secondary
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(pencilAttr).customAttribute(
                    RenderHowAttribute(noteIndicatorImage: true,
                                       noteIndicatorBox: true,
                                       noteIndicatorBoxColor: boxColor)
                )

                var verseAttr = t
                verseAttr.link = noteURL
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(verseAttr).customAttribute(
                    RenderHowAttribute(noteIndicatorBox: true,
                                       noteIndicatorBoxColor: boxColor)
                )

                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(" ")
                continue
            }
            let isUnderlined = isSelected(reference) && category == .scripture
            if isUnderlined {
                // Split by foreground color so WoC (red) text gets a red underline
                // while normal text uses the default verseSelectionStyle.color.
                for (fgColor, subRange) in t.runs[\.foregroundColor] {
                    let subStr = AttributedString(t[subRange])
                    // swiftlint:disable:next shorthand_operator
                    textCombo = textCombo + Text(subStr).customAttribute(
                        RenderHowAttribute(underlined: true, underlineColor: fgColor)
                    )
                }
            } else {
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(t).customAttribute(
                    RenderHowAttribute(footnoteImage: category == .footnoteImage)
                )
            }
        }

        let retValue = textCombo
            .tint(textOptions.textColor ?? .primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, (textOptions.paragraphSpacing ?? 0) / 2)
            .if(textOptions.lineSpacing != nil) { view in
                view.lineSpacing(textOptions.lineSpacing!)
            }
        if #available(iOS 18.0, *) {
            return retValue.textRenderer(BibleRenderer(verseSelectionStyle: textOptions.verseSelectionStyle))
        } else {
            return retValue  // TODO: can we support earlier iOS versions by using the generic underline?
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
        .padding(.top, ignoreMarginTop ? 0 : block.marginTop + ((textOptions.paragraphSpacing ?? 0) / 2))
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
