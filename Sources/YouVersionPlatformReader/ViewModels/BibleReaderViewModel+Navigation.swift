import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// How far the user must scroll to clear the focus.
private let focusScrollThreshold: CGFloat = 2

extension BibleReaderViewModel {
    func goToPreviousChapter() {
        guard let version else {
            return
        }
        isChangingChapter = true
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

        resetScrollStateForNewChapter()
    }

    func goToNextChapter() {
        guard let version else {
            return
        }
        isChangingChapter = true
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

        resetScrollStateForNewChapter()
    }

    /// Acts on any pending request from `readerNavigation`.
    func handleNavigationRequest(from readerNavigation: BibleReaderNavigation) {
        guard let request = readerNavigation.pendingRequest else {
            return
        }
        readerNavigation.clearPendingRequest()
        if request.shouldFocus && !request.scrollsToVerse {
            removeVerseSelection()
            focusReference(request.reference)
        } else {
            Task {
                await goToReference(request.reference, showsFullChapter: request.showsFullChapter, shouldFocus: request.shouldFocus)
            }
        }
    }

    func goToReference(_ reference: BibleReference, showsFullChapter: Bool = false, shouldFocus: Bool = false) async {
        await onHeaderSelectionChange(reference, showIntro: false)
        if reference == self.reference {
            self.showsFullChapter = showsFullChapter
            setScrollTarget(shouldFocus: shouldFocus)
        } else {
            finishChapterChange()
        }
    }

    func removeVerseSelection() {
        selectedVerses.removeAll()
        withAnimation(verseActionsDrawerAnimation) {
            showingVerseActionsDrawer = false
        }
    }

    func handleScroll(offset: CGFloat) {
        let previousOffset = lastScrollOffset
        lastScrollOffset = offset
        guard !isChangingChapter else {
            return
        }

        // A user scroll clears the focus.
        if focusedReference != nil, abs(offset - previousOffset) > focusScrollThreshold {
            clearFocus()
        }

        let threshold: CGFloat = 10
        let animation: Animation? = isReduceMotionEnabled ? nil : .easeInOut(duration: 0.1)
        // offset is the content's minY in the scroll viewport: 0 at top,
        // negative while scrolled down, positive when rubber-banding past top.
        if offset >= 0 {
            withAnimation(animation) { showChrome = true }
        } else if abs(offset - previousOffset) >= threshold {
            if offset < previousOffset - threshold {
                withAnimation(animation) { showChrome = false }
            } else if offset > previousOffset + threshold {
                withAnimation(animation) { showChrome = true }
            }
        }
    }

    func handleVerseTap(reference: BibleReference, actionType: String, footnotes: [BibleFootnote]) {
        if actionType == BibleVersionRendering.LinkSchemes.footnote.rawValue {
            showingFootnotes = true
            footnotesToDisplay = footnotes
            return
        }

        // Tapping a verse clears the focus.
        clearFocus()

        if let onVerseTap {
            onVerseTap(reference)
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
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "Reader")
            return
        }
        addHighlightOrStartPermissionFlow(references: selectedVerses, color: hex)
    }

    func removeVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            YouVersionPlatformLogger.error("Unable to convert color to hex: \(color)", category: "Reader")
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
        removeVerseSelection()
        clearFocus()
        do {
            if version?.id != reference.versionId {
                let newVersion = try await versionsViewModel.versionRepository.version(withId: reference.versionId)
                versionsViewModel.switchToVersion(newVersion)
                versionsViewModel.myVersions.insert(newVersion)
            }
            self.reference = reference
            self.showBookIntro = showIntro
            resetScrollStateForNewChapter()
        } catch {
            YouVersionPlatformLogger.error("Error loading version/chapter: \(error)", category: "Reader")
        }
    }

}
