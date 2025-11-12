import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

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
            if let books = version.books,
               let index = books.firstIndex(where: { $0.usfm == reference.bookUSFM }), index > 0 {
                let previousBook = books[index - 1]
                let maxChapter = previousBook.chapters?.count ?? 0
                reference = BibleReference(versionId: reference.versionId, bookUSFM: previousBook.usfm ?? "", chapter: maxChapter)
            }
        }

        // Reset scroll tracking to prevent chrome from hiding due to content change
        lastScrollOffset = 0
        scrollToTop = true
    }

    func goToNextChapter() {
        guard let version else {
            return
        }
        isChangingChapter = true
        removeVerseSelection()
        if let books = version.books,
           let index = books.firstIndex(where: { $0.usfm == reference.bookUSFM }) {
            let currentBook = books[index]
            let maxChapter = currentBook.chapters?.count ?? 0
            if reference.chapter < maxChapter {
                reference = BibleReference(versionId: reference.versionId, bookUSFM: currentBook.usfm ?? "", chapter: reference.chapter + 1)
            } else if index < books.count - 1 {
                let nextBook = books[index + 1]
                reference = BibleReference(versionId: reference.versionId, bookUSFM: nextBook.usfm ?? "", chapter: 1)
            }
        }

        // Reset scroll tracking to prevent chrome from hiding due to content change
        lastScrollOffset = 0
        scrollToTop = true
    }

    func removeVerseSelection() {
        selectedVerses.removeAll()
        showingVerseActionsDrawer = false
    }

    func handleScroll(offset: CGFloat) {
        guard !isChangingChapter else {
            return
        }

        let threshold: CGFloat = 10
        let animation: Animation = .easeInOut(duration: 0.1)
        if offset <= 0 {
            withAnimation(animation) { self.showChrome = true }
        } else if abs(offset - lastScrollOffset) >= threshold {
            if offset < lastScrollOffset - threshold {
                withAnimation(animation) { self.showChrome = false }
            } else if offset > lastScrollOffset + threshold {
                withAnimation(animation) { self.showChrome = true }
            }
        }
        lastScrollOffset = offset
    }

    // TODO the drawer needs to consider the color(s) of the highlighted verse(s), so it can add the X.
    func handleVerseTap(reference: BibleReference) {
        guard YouVersionAPI.isSignedIn else {
            showingSignInSheet = true
            return
        }
        
        if selectedVerses.contains(reference) {
            selectedVerses.remove(reference)
        } else {
            selectedVerses.insert(reference)
        }
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            showingVerseActionsDrawer = !self.selectedVerses.isEmpty
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

    private func isSameHexColor(_ a: String, _ b: String) -> Bool {
        let cleanA = a.starts(with: "#") ? String(a.split(separator: "#").last!) : a
        let cleanB = b.starts(with: "#") ? String(b.split(separator: "#").last!) : b
        return cleanA.localizedCaseInsensitiveCompare(cleanB) == .orderedSame
    }

    func addVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            print("Unable to convert color to hex: \(color)")
            return
        }
        highlightsViewModel.addHighlights(references: Array(selectedVerses), color: hex)
        removeVerseSelection()
    }

    func removeVerseColor(_ color: Color) {
        guard let hex = color.hexString else {
            print("Unable to convert color to hex: \(color)")
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

    func handleVerseActionCopy() {
        guard !selectedVerses.isEmpty else {
            return
        }
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        removeVerseSelection()
        Task {
            let t = await shareableVerseText(references: references)
            if let (url, title) = shareableURLAndTitleFor(references: references) {
                let data = "\(t)\n\(title)\n\(url.absoluteString)"
                #if canImport(UIKit)
                UIPasteboard.general.string = data
                #endif
            }
        }
    }

    func onHeaderSelectionChange(_ reference: BibleReference) async {
        isChangingChapter = true
        removeVerseSelection()
        do {
            if version?.id != reference.versionId {
                let newVersion = try await versionRepository.version(withId: reference.versionId)
                version = newVersion
                myVersions.insert(newVersion)
            }
            self.reference = reference

            // Reset scroll tracking to prevent chrome from hiding due to content change
            lastScrollOffset = 0
            scrollToTop = true
        } catch {
            print("Error loading version/chapter: \(error)")
        }
    }

}
