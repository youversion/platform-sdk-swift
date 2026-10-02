import SwiftUI
import YouVersionPlatform
@_spi(Typography) import YouVersionPlatformReader

/// Demonstrates driving the Bible reader from another tab via
/// ``BibleReaderNavigation``: each button requests a passage and switches to the
/// Bible tab, where the shared reader moves to it in place.
struct NavigateView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @State private var typographyPhase = "phase-3-global"

    private struct TypographyExample: Identifiable {
        let id: String
        let version: String
        let reference: BibleReference
        var showsIntroduction = false
        var footnoteIndex: Int?
    }

    private let typographyExamples: [TypographyExample] = [
        TypographyExample(id: "fp", version: "BLT", reference: BibleReference(versionId: 3254, bookId: "1SA", chapter: 10, verse: 27), footnoteIndex: 0),
        TypographyExample(id: "rq", version: "JCB", reference: BibleReference(versionId: 83, bookId: "2CO", chapter: 13, verse: 1)),
        TypographyExample(id: "r", version: "LSG", reference: BibleReference(versionId: 93, bookId: "GEN", chapter: 1)),
        TypographyExample(id: "imt3", version: "LSG", reference: BibleReference(versionId: 93, bookId: "EXO", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "is1", version: "LSG", reference: BibleReference(versionId: 93, bookId: "MAT", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "lh + sr", version: "NVI-S", reference: BibleReference(versionId: 128, bookId: "GEN", chapter: 10)),
        TypographyExample(id: "litl", version: "NVI-S", reference: BibleReference(versionId: 128, bookId: "EZR", chapter: 2, verse: 3)),
        TypographyExample(id: "po", version: "NVI-S", reference: BibleReference(versionId: 128, bookId: "ROM", chapter: 1)),
        TypographyExample(id: "pn", version: "CCB", reference: BibleReference(versionId: 36, bookId: "GEN", chapter: 4))
    ]

    private let englishTypographyExamples: [TypographyExample] = [
        TypographyExample(id: "imt", version: "TPT", reference: BibleReference(versionId: 1849, bookId: "GEN", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "imq", version: "TPT", reference: BibleReference(versionId: 1849, bookId: "JOS", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "cls", version: "TPT", reference: BibleReference(versionId: 1849, bookId: "TIT", chapter: 3, verse: 15)),
        TypographyExample(id: "bd-s", version: "NASB1995", reference: BibleReference(versionId: 100, bookId: "LEV", chapter: 21)),
        TypographyExample(id: "em", version: "PEV", reference: BibleReference(versionId: 2530, bookId: "GEN", chapter: 4)),
        TypographyExample(id: "li", version: "PEV", reference: BibleReference(versionId: 2530, bookId: "GEN", chapter: 36)),
        TypographyExample(id: "sig", version: "PEV", reference: BibleReference(versionId: 2530, bookId: "GAL", chapter: 6, verse: 11)),
        TypographyExample(id: "fk", version: "TOJB2011", reference: BibleReference(versionId: 130, bookId: "ISA", chapter: 11, verse: 1), footnoteIndex: 0),
        TypographyExample(id: "qac-va", version: "TOJB2011", reference: BibleReference(versionId: 130, bookId: "PSA", chapter: 25)),
        TypographyExample(id: "fl", version: "WEBUS", reference: BibleReference(versionId: 206, bookId: "ESG", chapter: 1, verse: 1), footnoteIndex: 1),
        TypographyExample(id: "lim", version: "NASB2020", reference: BibleReference(versionId: 2692, bookId: "REV", chapter: 7, verse: 5))
    ]

    private let globalTypographyExamples: [TypographyExample] = [
        TypographyExample(id: "global-mt", version: "yak", reference: BibleReference(versionId: 1388, bookId: "RUT", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-imte", version: "Susu", reference: BibleReference(versionId: 893, bookId: "GEN", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-imte1", version: "bnoNTgnex", reference: BibleReference(versionId: 2174, bookId: "GEN", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-imte2", version: "kogNT", reference: BibleReference(versionId: 1505, bookId: "MAT", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-cd", version: "WAT", reference: BibleReference(versionId: 1473, bookId: "EXO", chapter: 40)),
        TypographyExample(id: "global-qd", version: "ggaNTP", reference: BibleReference(versionId: 4231, bookId: "PSA", chapter: 74)),
        TypographyExample(id: "global-sls", version: "rov", reference: BibleReference(versionId: 1909, bookId: "PSA", chapter: 9)),
        TypographyExample(id: "global-k", version: "WLB", reference: BibleReference(versionId: 2093, bookId: "JOS", chapter: 23)),
        TypographyExample(id: "global-lim1", version: "LIF", reference: BibleReference(versionId: 252, bookId: "NEH", chapter: 7, verse: 8)),
        TypographyExample(id: "global-imi-iqt-ipr", version: "NLT", reference: BibleReference(versionId: 2652, bookId: "GEN", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-ipq", version: "zga", reference: BibleReference(versionId: 2312, bookId: "MRK", chapter: 1), showsIntroduction: true),
        TypographyExample(id: "global-iot", version: "NRT", reference: BibleReference(versionId: 143, bookId: "GEN", chapter: 1), showsIntroduction: true)
    ]

    private var selectedTypographyExamples: [TypographyExample] {
        switch typographyPhase {
        case "phase-2": englishTypographyExamples
        case "phase-3": typographyExamples
        default: globalTypographyExamples
        }
    }

    private let examples: [(title: String, reference: BibleReference, showsFullChapter: Bool, shouldFocus: Bool)] = [
        (
            String(localized: "navigate.john_3_16_full_chapter"),
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            false
        ),
        (
            String(localized: "navigate.john_3_16_focused"),
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            true
        ),
        (
            String(localized: "navigate.psalm_118_1_focused"),
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 118, verse: 1),
            true,
            true
        ),
        (
            String(localized: "navigate.psalm_119_105_full_chapter"),
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 119, verse: 105),
            true,
            false
        ),
        (
            String(localized: "navigate.romans_8_28_verse_range"),
            BibleReference(versionId: 3034, bookId: "ROM", chapter: 8, verse: 28),
            false,
            false
        ),
        (
            String(localized: "navigate.genesis_1_whole_chapter"),
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 1),
            true,
            false
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Typography") {
                    Picker("Typography phase", selection: $typographyPhase) {
                        Text(verbatim: "Phase 2").tag("phase-2")
                        Text(verbatim: "Phase 3").tag("phase-3")
                        Text(verbatim: "Phase 3 (global)").tag("phase-3-global")
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(selectedTypographyExamples) { example in
                            Button {
                                navigation.requestTypography(
                                    example.reference,
                                    showsIntroduction: example.showsIntroduction,
                                    footnoteIndex: example.footnoteIndex
                                )
                                onNavigate()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(example.id).font(.headline)
                                    Text(example.version).font(.caption)
                                    Text(example.showsIntroduction ? "\(example.reference.bookId) intro" : example.reference.passageId)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("typography-\(example.id)")
                        }
                    }
                    if let error = navigation.typographyError {
                        Text(error).foregroundStyle(.red)
                    }
                    Text("Opens the Reader directly. fp, fk and fl open footnotes. imq and is1 need introduction scrolling.")
                        .font(.caption)
                }
                Section {
                    ForEach(examples, id: \.title) { example in
                        Button(example.title) {
                            if example.shouldFocus, #available(iOS 18.0, *) {
                                navigation.focusReference(example.reference)
                            } else {
                                navigation.request(example.reference, showsFullChapter: example.showsFullChapter)
                            }
                            onNavigate()
                        }
                    }
                } footer: {
                    Text("navigate.footer")
                }
            }
            .navigationTitle("navigate.title")
        }
    }
}
