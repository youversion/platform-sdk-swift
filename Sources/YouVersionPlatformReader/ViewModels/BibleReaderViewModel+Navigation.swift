import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    func goToPreviousChapter() {
        guard let version else {
            return
        }
        isChangingChapter = true
        resetChapterCompleteTracking()
        removeVerseSelection()
        if reference.chapter > 1 {
            reference = BibleReference(versionId: reference.versionId, bookUSFM: reference.bookUSFM, chapter: reference.chapter - 1)
        } else {
            if let books = version.books, let bookIndex = books.firstIndex(where: { $0.id == reference.bookUSFM }) {
                if showBookIntro == false && books[bookIndex].intro != nil {
                    showBookIntro = true  // and leave the reference at chapter 1
                } else if bookIndex > 0 {
                    let previousBook = books[bookIndex - 1]
                    let maxChapter = previousBook.chapters?.count ?? 0
                    reference = BibleReference(versionId: reference.versionId, bookUSFM: previousBook.id ?? "", chapter: maxChapter)
                    showBookIntro = false
                }
            }
        }

        // Reset scroll tracking and restore chrome so the new chapter lands
        // in the same initial state as a fresh open. Without this, chrome
        // stays hidden after a navigation tap that scrolls cached content
        // back to minY = 0, since onGeometryChange won't fire again.
        lastScrollOffset = 0
        showChrome = true
        scrollToTop = true
    }

    func goToNextChapter() {
        guard let version else {
            return
        }
        isChangingChapter = true
        resetChapterCompleteTracking()
        removeVerseSelection()
        if let books = version.books, let index = books.firstIndex(where: { $0.id == reference.bookUSFM }) {
            let currentBook = books[index]
            let maxChapter = currentBook.chapters?.count ?? 0
            if showBookIntro {
                reference = BibleReference(versionId: reference.versionId, bookUSFM: currentBook.id ?? "", chapter: 1)
                showBookIntro = false
            } else if reference.chapter < maxChapter {
                reference = BibleReference(versionId: reference.versionId, bookUSFM: currentBook.id ?? "", chapter: reference.chapter + 1)
            } else if index < books.count - 1 {
                let nextBook = books[index + 1]
                reference = BibleReference(versionId: reference.versionId, bookUSFM: nextBook.id ?? "", chapter: 1)
                if nextBook.intro != nil {
                    showBookIntro = true
                }
            }
        }

        // Reset scroll tracking and restore chrome so the new chapter lands
        // in the same initial state as a fresh open. Without this, chrome
        // stays hidden after a navigation tap that scrolls cached content
        // back to minY = 0, since onGeometryChange won't fire again.
        lastScrollOffset = 0
        showChrome = true
        scrollToTop = true
    }

    func removeVerseSelection() {
        selectedVerses.removeAll()
        showingVerseActionsDrawer = false
    }

    func handleScroll(offset: CGFloat, contentHeight: CGFloat) {
        // Always record the latest geometry so a freshly-navigated chapter has
        // its contentHeight ready the moment the isChangingChapter guard clears.
        // Without this, short chapters reached via prev/next would never fire
        // onChapterComplete: every geometry event during the 0.5s scroll-reset
        // window would be dropped, leaving contentHeight at 0 and no further
        // scroll events to populate it.
        let previousScrollOffset = lastScrollOffset
        lastScrollOffset = offset
        previousContentHeight = self.contentHeight
        self.contentHeight = contentHeight

        guard !isChangingChapter else {
            return
        }

        let threshold: CGFloat = 10
        let animation: Animation? = isReduceMotionEnabled ? nil : .easeInOut(duration: 0.1)
        // offset is the content's minY in the scroll viewport: 0 at top,
        // negative while scrolled down, positive when rubber-banding past top.
        if offset >= 0 {
            withAnimation(animation) { self.showChrome = true }
        } else if abs(offset - previousScrollOffset) >= threshold {
            if offset < previousScrollOffset - threshold {
                withAnimation(animation) { self.showChrome = false }
            } else if offset > previousScrollOffset + threshold {
                withAnimation(animation) { self.showChrome = true }
            }
        }

        evaluateChapterCompleteFromCachedGeometry()
    }

    /// Fires `onChapterComplete` if the latest cached geometry indicates the
    /// bottom of the content is in view. Safe to call any time; gated by
    /// `hasNotifiedChapterComplete` so it fires at most once per chapter.
    func evaluateChapterCompleteFromCachedGeometry() {
        // The bottom of the content has come into view when the content's
        // bottom edge (offset + contentHeight) is at or above the viewport's
        // bottom edge (scrollViewHeight). The small epsilon absorbs subpixel
        // rounding so we don't miss a fire by a hair.
        let bottomEpsilon: CGFloat = 8
        let bottomReached = scrollViewHeight > 0
            && contentHeight > 0
            && (lastScrollOffset + contentHeight) <= (scrollViewHeight + bottomEpsilon)

        // Require contentHeight to be stable across two consecutive geometry
        // events. BibleTextView loads its blocks asynchronously, so the first
        // layout pass reports a small contentHeight (just the copyright block
        // and padding) that can spuriously satisfy the bottom-reached check.
        // Waiting for a stable height ensures we only fire once the chapter
        // text has actually rendered.
        let heightIsStable = contentHeight == previousContentHeight

        if bottomReached
            && heightIsStable
            && version != nil
            && !hasNotifiedChapterComplete
            && !isChangingChapter {
            hasNotifiedChapterComplete = true
            onChapterComplete?(reference)
        }
    }

    func resetChapterCompleteTracking() {
        hasNotifiedChapterComplete = false
        contentHeight = 0
        previousContentHeight = 0
    }

    func handleVerseTap(reference: BibleReference, actionType: String, footnotes: [BibleFootnote]) {
        if actionType == BibleVersionRendering.LinkSchemes.footnote.rawValue {
            showingFootnotes = true
            footnotesToDisplay = footnotes
            return
        }

        if actionType == BibleVersionRendering.LinkSchemes.noteIndicator.rawValue {
            onNoteIndicatorTap?(reference)
            return
        }
        
        if selectedVerses.contains(reference) {
            selectedVerses.remove(reference)
        } else {
            selectedVerses.insert(reference)
        }
        withAnimation(verseActionsDrawerAnimation) {
            showingVerseActionsDrawer = !selectedVerses.isEmpty
        }
    }

    private func selectedVersesWithColor(_ color: Color) -> Set<BibleReference> {
        guard let hex = color.hexString else {
            return []
        }
        return Set(selectedVerses.filter { reference in
            highlightsViewModel.highlights(for: reference).contains { highlight in
                isSameHexColor(highlight.color, hex)
            }
        })
    }

    func isColorPresentOnAnySelectedVerses(_ color: Color) -> Bool {
        !selectedVersesWithColor(color).isEmpty
    }

    func isColorPresentOnAllSelectedVerses(_ color: Color) -> Bool {
        !selectedVerses.isEmpty && selectedVersesWithColor(color).count == selectedVerses.count
    }

    func hexColorValueForComparison(_ color: String) -> String {
        guard color.starts(with: "#") else {
            return color
        }
        return String(color.dropFirst())
    }

    func isSameHexColor(_ a: String, _ b: String) -> Bool {
        let cleanA = hexColorValueForComparison(a)
        let cleanB = hexColorValueForComparison(b)
        return cleanA.localizedCaseInsensitiveCompare(cleanB) == .orderedSame
    }

    func addVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "BibleReader")
            return
        }
        addHighlightOrStartPermissionFlow(references: selectedVerses, color: hex)
    }

    func removeVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "BibleReader")
            return
        }
        for reference in selectedVerses {
            let highlights = highlightsViewModel.highlights(for: reference)
            for highlight in highlights where isSameHexColor(highlight.color, hex) {
                highlightsViewModel.removeHighlights(references: [reference])
            }
        }
        removeVerseSelection()
    }

    func shareableVerseText(references: [BibleReference]) async -> String {
        guard !references.isEmpty else {
            return ""
        }
        var pieces: [String] = []
        for reference in references {
            let referenceText = try? await BibleVersionRendering.plainTextOf(reference)
            pieces.append(referenceText ?? .localized("shareableVerse.unavailable"))
        }
        return pieces.joined(separator: "\n")
    }

    var shareableURLAndTitleForSelection: (URL, String)? {
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        return shareableURLAndTitleFor(references: references)
    }

    func shareableURLAndTitleFor(references: [BibleReference]) -> (URL, String)? {
        guard let version,
              !references.isEmpty,
              // Bug, maybe: this URL only points to the first reference in possibly several.
              // Discontiguous selection could benefit from multiple urls...
              let url = version.shareUrl(reference: references.first!)
        else {
            return nil
        }
        // the below would be nicer if it could emit e.g. "John 1:2, 4" instead of "John 1:2, John 1:4"
        let referenceTitles = references.map( { version.displayTitle(for: $0, includesVersionAbbreviation: true) })
        let referenceTitlesJoined = referenceTitles.joined(separator: .localized("shareableVerse.referencesSeparator"))

        return (url, referenceTitlesJoined)
    }

    @discardableResult
    // swiftlint:disable:next var_over_func
    func handleVerseActionCopy() -> Task<Void, Never>? {
        guard !selectedVerses.isEmpty else {
            return nil
        }
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        removeVerseSelection()
        return Task {
            let t = await shareableVerseText(references: references)
            if let (url, title) = shareableURLAndTitleFor(references: references) {
                let data = "\(t)\n\(title)\n\(url.absoluteString)"
                #if canImport(UIKit)
#if !os(tvOS)
                UIPasteboard.general.string = data
#endif
                #endif
            }
        }
    }

    func onHeaderSelectionChange(_ reference: BibleReference, showIntro: Bool) async {
        isChangingChapter = true
        resetChapterCompleteTracking()
        removeVerseSelection()
        do {
            if version?.id != reference.versionId {
                let newVersion = try await versionsViewModel.versionRepository.version(withId: reference.versionId)
                versionsViewModel.switchToVersion(newVersion)
                versionsViewModel.myVersions.insert(newVersion)
            }
            self.reference = reference
            self.showBookIntro = showIntro

            // Reset scroll tracking and restore chrome so the new chapter lands
            // in the same initial state as a fresh open. Without this, chrome
            // stays hidden after a navigation tap that scrolls cached content
            // back to minY = 0, since onGeometryChange won't fire again.
            lastScrollOffset = 0
            showChrome = true
            scrollToTop = true
        } catch {
            YouVersionPlatformLogger.error("Error loading version/chapter: \(error)", category: "BibleReader")
        }
    }

}
