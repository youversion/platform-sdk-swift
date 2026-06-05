import SwiftUI
import YouVersionPlatformCore

extension BibleTextView {
    @ViewBuilder
    func view(for block: BibleTextBlock, textOptions: BibleTextOptions, ignoreMarginTop: Bool, previousMarginBottom: CGFloat) -> some View {
        if block.rows.isEmpty {
            let theView = emitTextBlock(block, textOptions: textOptions, ignoreMarginTop: ignoreMarginTop, previousMarginBottom: previousMarginBottom)
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
        let nbsp = "\u{00a0}"
        return AttributedString(String(repeating: nbsp, count: min(max(indent * 3, 0), 24)))
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
        let audioActiveIndicatorColor: Color?
        let audioActiveVerse: Int?

        init(verseSelectionStyle: VerseSelectionStyle = .solid, audioActiveIndicatorColor: Color? = nil, audioActiveVerse: Int? = nil) {
            footnoteIcon = Image("footnoteIcon", bundle: .YouVersionUIBundle)
            noteIndicatorIcon = Image("noteIndicatorIcon", bundle: .YouVersionUIBundle)
            self.verseSelectionStyle = verseSelectionStyle
            self.audioActiveIndicatorColor = audioActiveIndicatorColor
            self.audioActiveVerse = audioActiveVerse
        }

        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            let footnoteImage = context.resolve(footnoteIcon)
            let noteIndicatorImage = context.resolve(noteIndicatorIcon)

            // Union typographic bounds of runs for the active verse only — not full `line` bounds.
            // Multiple verses often share one typographic line in a paragraph; using the whole line
            // incorrectly stretched the bar across neighboring verses.
            if let indicatorColor = audioActiveIndicatorColor, let activeVerse = audioActiveVerse {
                var barMinY: CGFloat?
                var barMaxY: CGFloat?
                var barX: CGFloat = .infinity
                for line in layout {
                    for run in line where run[RenderHowAttribute.self]?.verseNumber == activeVerse {
                        let runRect = run.typographicBounds.rect
                        barMinY = min(barMinY ?? .infinity, runRect.minY)
                        barMaxY = max(barMaxY ?? -.infinity, runRect.maxY)
                        barX = min(barX, runRect.minX)
                    }
                }
                if let minY = barMinY, let maxY = barMaxY {
                    let barWidth: CGFloat = 3
                    let barRect = CGRect(x: barX - 12, y: minY, width: barWidth, height: maxY - minY)
                    let path = RoundedRectangle(cornerRadius: 1.5).path(in: barRect)
                    context.fill(path, with: .color(indicatorColor))
                }
            }

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
                    let boxRect = CGRect(
                        x: start - padding,
                        y: boxY,
                        width: (boxEnd - start) + padding * 2,
                        height: boxHeight
                    )
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
                    } else if let termColor = attrs?.termTextColor {
                        // The term carries a `.link` (for tap routing), so SwiftUI would
                        // color it with the global `.tint`. Recolor its glyphs by masking a
                        // fill to the drawn text (`.sourceAtop`).
                        context.drawLayer { layer in
                            layer.draw(run)
                            layer.blendMode = .sourceAtop
                            layer.fill(Path(run.typographicBounds.rect), with: .color(termColor))
                        }
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
        var audioActive = false
        var verseNumber: Int?
        var footnoteImage = false
        var noteIndicatorImage = false
        var noteIndicatorBox = false
        var noteIndicatorBoxColor: Color?
        /// Text color for a collectible term. Set on the term's run so the renderer can
        /// paint its glyphs in this color, overriding the global `.tint` that links use.
        var termTextColor: Color?
    }

    private func textView(for double: BibleAttributedString, firstLineHeadIndent: Int, blockId: UUID, textOptions: BibleTextOptions) -> some View {
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
            if category == .scripture {
                applyTermHighlights(to: &t, reference: reference)
            }
            if category == .verseLabel, let reference,
               noteIndicatedUSFMs.contains("\(reference.versionId):\(reference.asUSFM)") {
                let hasHighlight = highlightFor(reference: reference) != .clear
                let boxColor = hasHighlight
                    ? textOptions.noteIndicatorBoxHighlightColor
                    : textOptions.noteIndicatorBoxColor
                let highlightColor = highlightFor(reference: reference)
                let noteURL = URL(string: "\(BibleVersionRendering.LinkSchemes.noteIndicator.rawValue)://\(reference.versionId)/\(reference.asUSFM)")

                var pencilAttr = AttributedString("\u{2003}")
                pencilAttr.link = noteURL
                pencilAttr.foregroundColor = textOptions.verseNumberColor ?? .secondary
                pencilAttr.backgroundColor = highlightColor
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(pencilAttr).customAttribute(
                    RenderHowAttribute(
                        noteIndicatorImage: true,
                        noteIndicatorBox: true,
                        noteIndicatorBoxColor: boxColor
                    )
                )

                var spacerAttr = AttributedString("\u{2009}")
                spacerAttr.link = noteURL
                spacerAttr.foregroundColor = textOptions.verseNumberColor ?? .secondary
                spacerAttr.backgroundColor = highlightColor
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(spacerAttr).customAttribute(
                    RenderHowAttribute(
                        noteIndicatorBox: true,
                        noteIndicatorBoxColor: boxColor
                    )
                )

                var verseAttr = t
                verseAttr.link = noteURL
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(verseAttr).customAttribute(
                    RenderHowAttribute(
                        noteIndicatorBox: true,
                        noteIndicatorBoxColor: boxColor
                    )
                )

                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(" ")
                continue
            }
            let isUnderlined = (reference.map(isSelected) ?? false) && category == .scripture
            let isActive = isAudioActive(reference) && (category == .scripture || category == .verseLabel)
            let verse = reference?.verseStart
            if isUnderlined {
                for (fgColor, subRange) in t.runs[\.foregroundColor] {
                    let subStr = AttributedString(t[subRange])
                    // swiftlint:disable:next shorthand_operator
                    textCombo = textCombo + Text(subStr).customAttribute(
                        RenderHowAttribute(underlined: true, underlineColor: fgColor, audioActive: isActive, verseNumber: verse)
                    )
                }
            } else if category == .scripture {
                // Emit scripture run-by-run so a collectible term carries its own text
                // color for the renderer to apply (its `.link` would otherwise force the
                // global `.tint` color).
                appendTermAwareRuns(
                    t,
                    base: RenderHowAttribute(audioActive: isActive, verseNumber: verse),
                    to: &textCombo
                )
            } else if isActive {
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(t).customAttribute(
                    RenderHowAttribute(audioActive: true, verseNumber: verse, footnoteImage: category == .footnoteImage)
                )
            } else {
                // swiftlint:disable:next shorthand_operator
                textCombo = textCombo + Text(t).customAttribute(
                    RenderHowAttribute(verseNumber: verse, footnoteImage: category == .footnoteImage)
                )
            }
        }

        let retValue = textCombo
            // Verse runs carry link attributes (for OpenURLAction tap routing), so the
            // effective text color comes from .tint, not .foregroundStyle.
            .tint(textOptions.textColor ?? .primary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(fontRelativeLineSpacing(textOptions: textOptions))
        if #available(iOS 18.0, *) {
            return retValue.textRenderer(BibleRenderer(
                verseSelectionStyle: textOptions.verseSelectionStyle,
                audioActiveIndicatorColor: textOptions.audioActiveIndicatorColor,
                audioActiveVerse: audioActiveVerse
            ))
        } else {
            return retValue
        }
    }
    
    private func fontRelativeLineSpacing(textOptions: BibleTextOptions) -> CGFloat {
        textOptions.fontSize * (textOptions.lineSpacing ?? 0.4)
    }

    /// ignoreMarginTop is used so that the topmost block won't have a top margin applied.
    /// previousMarginBottom is provided so that it and the current marginTop can be merged together, mirroring how CSS works.
    private func emitTextBlock(_ block: BibleTextBlock, textOptions: BibleTextOptions, ignoreMarginTop: Bool, previousMarginBottom: CGFloat) -> some View {
        textView(
            for: block.text,
            firstLineHeadIndent: block.firstLineHeadIndent,
            blockId: block.id,
            textOptions: textOptions
        )
        .multilineTextAlignment(block.alignment)
        .padding(.leading, CGFloat(8 * block.headIndent))
        .padding(.top, ignoreMarginTop ? 0 : max(0, block.marginTop - previousMarginBottom))
        .padding(.bottom, block.marginBottom + fontRelativeLineSpacing(textOptions: textOptions) + (textOptions.paragraphSpacing ?? 0.0))
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
                    ForEach(Array(row.doubles.enumerated()), id: \.element) { index, cell in
                        let isTrailingCell = index == row.doubles.count - 1 && index > 0
                        // below works around a Grid weirdness where it would add extra space
                        let string = cell.double.characters.isEmpty ? BibleAttributedString(" ") : cell.double
                        textView(
                            for: string,
                            firstLineHeadIndent: 0,
                            blockId: cell.id,
                            textOptions: textOptions
                        )
                        .fixedSize(horizontal: isTrailingCell, vertical: true)
                        .frame(
                            maxWidth: index == 0 ? .infinity : nil,
                            alignment: isTrailingCell ? .trailing : .leading
                        )
                        .gridColumnAlignment(isTrailingCell ? .trailing : .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func isAudioActive(_ reference: BibleReference?) -> Bool {
        guard let audioActiveVerse, let reference else {
            return false
        }
        return reference.verseStart == audioActiveVerse
    }

    /// Applies a distinct background and a tappable `collectible://<id>` link to the
    /// first case-insensitive occurrence of each matching term within this scripture run.
    /// The link overrides the verse-level tap link only on the term's character range, so
    /// footnote and cross-reference tap targets (separate runs) are unaffected.
    /// Concatenates a scripture run's sub-runs onto `textCombo`, tagging any collectible
    /// term run with its text color via ``RenderHowAttribute/termTextColor`` so the
    /// renderer can paint it (a term's `.link` otherwise forces the global `.tint`).
    private func appendTermAwareRuns(
        _ t: AttributedString,
        base: RenderHowAttribute,
        to textCombo: inout Text
    ) {
        let collectibleScheme = BibleVersionRendering.LinkSchemes.collectible.rawValue
        for (link, foregroundColor, range) in t.runs[\.link, \.foregroundColor] {
            let subStr = AttributedString(t[range])
            var attr = base
            if link?.scheme == collectibleScheme {
                attr.termTextColor = foregroundColor
            }
            // swiftlint:disable:next shorthand_operator
            textCombo = textCombo + Text(subStr).customAttribute(attr)
        }
    }

    private func applyTermHighlights(to t: inout AttributedString, reference: BibleReference?) {
        guard let reference else {
            return
        }
        let plain = String(t.characters)
        guard !plain.isEmpty else {
            return
        }
        for highlight in ourTermHighlights {
            guard highlight.appliesTo(verse: reference),
                  let matched = highlight.firstMatchRange(in: plain) else {
                continue
            }
            let lower = plain.distance(from: plain.startIndex, to: matched.lowerBound)
            let upper = plain.distance(from: plain.startIndex, to: matched.upperBound)
            let chars = t.characters
            guard let start = chars.index(chars.startIndex, offsetBy: lower, limitedBy: chars.endIndex),
                  let end = chars.index(chars.startIndex, offsetBy: upper, limitedBy: chars.endIndex) else {
                continue
            }
            t[start..<end].backgroundColor = Color(hex: highlight.color)
            if let textColor = highlight.textColor {
                t[start..<end].foregroundColor = Color(hex: textColor)
            }
            t[start..<end].link = BibleVersionRendering.collectibleLink(id: highlight.id)
        }
    }

    private func highlightFor(reference: BibleReference?) -> Color {
        guard let reference else {
            return .clear
        }
        for highlight in ourHighlights {
            if highlight.reference.chapter == reference.chapter && highlight.reference.verseStart == reference.verseStart {
                return Color(hex: highlight.color).opacity(0.35)
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
