import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

struct BookFixture: Sendable {
    let id: String
    let chapterCount: Int
    let hasIntro: Bool
}

struct NextChapterCase: Sendable {
    let name: String
    let books: [BookFixture]
    let referenceBook: String
    let referenceChapter: Int
    let showBookIntro: Bool
    let expectedBook: String
    let expectedChapter: Int
    let expectedShowBookIntro: Bool
}

struct PreviousChapterCase: Sendable {
    let name: String
    let books: [BookFixture]
    let referenceBook: String
    let referenceChapter: Int
    let showBookIntro: Bool
    let expectedBook: String
    let expectedChapter: Int
    let expectedShowBookIntro: Bool
}

let nextChapterCases: [NextChapterCase] = [
    NextChapterCase(
        name: "intro-visible-advances-to-chapter-one",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 1,
        showBookIntro: true,
        expectedBook: "GEN",
        expectedChapter: 1,
        expectedShowBookIntro: false
    ),
    NextChapterCase(
        name: "chapter-one-advances-to-two",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 1,
        showBookIntro: false,
        expectedBook: "GEN",
        expectedChapter: 2,
        expectedShowBookIntro: false
    ),
    NextChapterCase(
        name: "chapter-two-advances-to-three",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 2,
        showBookIntro: false,
        expectedBook: "GEN",
        expectedChapter: 3,
        expectedShowBookIntro: false
    ),
    NextChapterCase(
        name: "end-of-book-advances-to-next-book-chapter-one",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 3,
        showBookIntro: false,
        expectedBook: "EXO",
        expectedChapter: 1,
        expectedShowBookIntro: false
    ),
    NextChapterCase(
        name: "one-chapter-book-advances-to-next-book",
        books: [
            BookFixture(id: "PHM", chapterCount: 1, hasIntro: false),
            BookFixture(id: "HEB", chapterCount: 13, hasIntro: true),
        ],
        referenceBook: "PHM",
        referenceChapter: 1,
        showBookIntro: false,
        expectedBook: "HEB",
        expectedChapter: 1,
        expectedShowBookIntro: true
    ),
    NextChapterCase(
        name: "last-book-last-chapter-stays-put",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "EXO",
        referenceChapter: 2,
        showBookIntro: false,
        expectedBook: "EXO",
        expectedChapter: 2,
        expectedShowBookIntro: false
    ),
]

let previousChapterCases: [PreviousChapterCase] = [
    PreviousChapterCase(
        name: "chapter-two-goes-to-one",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 2,
        showBookIntro: false,
        expectedBook: "GEN",
        expectedChapter: 1,
        expectedShowBookIntro: false
    ),
    PreviousChapterCase(
        name: "chapter-three-goes-to-two",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "GEN",
        referenceChapter: 3,
        showBookIntro: false,
        expectedBook: "GEN",
        expectedChapter: 2,
        expectedShowBookIntro: false
    ),
    PreviousChapterCase(
        name: "chapter-one-with-intro-shows-intro",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: true),
        ],
        referenceBook: "EXO",
        referenceChapter: 1,
        showBookIntro: false,
        expectedBook: "EXO",
        expectedChapter: 1,
        expectedShowBookIntro: true
    ),
    PreviousChapterCase(
        name: "chapter-one-no-intro-goes-to-previous-book-last-chapter",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "EXO",
        referenceChapter: 1,
        showBookIntro: false,
        expectedBook: "GEN",
        expectedChapter: 3,
        expectedShowBookIntro: false
    ),
    PreviousChapterCase(
        name: "one-chapter-book-goes-to-previous-book-last-chapter",
        books: [
            BookFixture(id: "JAS", chapterCount: 5, hasIntro: false),
            BookFixture(id: "PHM", chapterCount: 1, hasIntro: true),
        ],
        referenceBook: "PHM",
        referenceChapter: 1,
        showBookIntro: false,
        expectedBook: "PHM",
        expectedChapter: 1,
        expectedShowBookIntro: true
    ),
    PreviousChapterCase(
        name: "intro-visible-goes-to-previous-book-last-chapter",
        books: [
            BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: false),
        ],
        referenceBook: "EXO",
        referenceChapter: 1,
        showBookIntro: true,
        expectedBook: "GEN",
        expectedChapter: 3,
        expectedShowBookIntro: false
    ),
]

@MainActor
@Suite struct BibleReaderViewModelNavigationTests {
    private static let versionId = 3034

    @Test(arguments: [false, true])
    func goToNextChapterWithoutLoadedVersionDoesNothing(_ showIntro: Bool) {
        let vm = BibleReaderViewModel(
            reference: BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2)
        )
        let selectedReference = BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2, verse: 1)
        vm.showBookIntro = showIntro
        // currentVersion is nil by default — the "no loaded version" state.
        vm.isChangingChapter = false
        vm.lastScrollOffset = 123
        vm.scrollToTop = false
        vm.selectedVerses = [selectedReference]
        vm.showingVerseActionsDrawer = true

        vm.goToNextChapter()

        #expect(vm.reference == BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2))
        #expect(vm.showBookIntro == showIntro)
        #expect(vm.isChangingChapter == false)
        #expect(vm.lastScrollOffset == 123)
        #expect(vm.scrollToTop == false)
        #expect(vm.selectedVerses == [selectedReference])
        #expect(vm.showingVerseActionsDrawer == true)
    }

    @Test(arguments: [false, true])
    func goToPreviousChapterWithoutLoadedVersionDoesNothing(_ showIntro: Bool) {
        let vm = BibleReaderViewModel(
            reference: BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2)
        )
        let selectedReference = BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2, verse: 1)
        vm.showBookIntro = showIntro
        // currentVersion is nil by default — the "no loaded version" state.
        vm.isChangingChapter = false
        vm.lastScrollOffset = 123
        vm.scrollToTop = false
        vm.selectedVerses = [selectedReference]
        vm.showingVerseActionsDrawer = true

        vm.goToPreviousChapter()

        #expect(vm.reference == BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 2))
        #expect(vm.showBookIntro == showIntro)
        #expect(vm.isChangingChapter == false)
        #expect(vm.lastScrollOffset == 123)
        #expect(vm.scrollToTop == false)
        #expect(vm.selectedVerses == [selectedReference])
        #expect(vm.showingVerseActionsDrawer == true)
    }

    @Test(arguments: [
        (BookFixture(id: "GEN", chapterCount: 3, hasIntro: true), true),
        (BookFixture(id: "JUD", chapterCount: 1, hasIntro: false), false),
    ])
    func goToPreviousChapterFromFirstBookStaysPut(_ arguments: (BookFixture, Bool)) {
        let firstBook = arguments.0
        let expectedShowBookIntro = arguments.1
        let books = [
            firstBook,
            BookFixture(id: "EXO", chapterCount: 2, hasIntro: true),
        ]
        let vm = makeViewModel(
            books: books,
            referenceBook: firstBook.id,
            referenceChapter: 1,
            showBookIntro: false
        )

        vm.goToPreviousChapter()

        #expect(vm.reference == BibleReference(versionId: Self.versionId, bookUSFM: firstBook.id, chapter: 1))
        #expect(vm.showBookIntro == expectedShowBookIntro)
        assertNavigationSideEffects(on: vm)
    }

    @Test(arguments: [
        BookFixture(id: "GEN", chapterCount: 3, hasIntro: true),
        BookFixture(id: "JUD", chapterCount: 1, hasIntro: false),
    ])
    func goToNextChapterFromSingleBookAtEndStaysPut(_ onlyBook: BookFixture) {
        let vm = makeViewModel(
            books: [onlyBook],
            referenceBook: onlyBook.id,
            referenceChapter: onlyBook.chapterCount,
            showBookIntro: false
        )

        vm.goToNextChapter()

        #expect(vm.reference == BibleReference(versionId: Self.versionId, bookUSFM: onlyBook.id, chapter: onlyBook.chapterCount))
        #expect(vm.showBookIntro == false)
        assertNavigationSideEffects(on: vm)
    }

    @Test(arguments: nextChapterCases)
    func goToNextChapterTransitionsCorrectly(_ testCase: NextChapterCase) {
        let vm = makeViewModel(
            books: testCase.books,
            referenceBook: testCase.referenceBook,
            referenceChapter: testCase.referenceChapter,
            showBookIntro: testCase.showBookIntro
        )
        let expectedBookIds = testCase.books.map(\.id)
        let actualBookIds = vm.version?.books?.compactMap { $0.id } ?? []
        #expect(actualBookIds == expectedBookIds, Comment("Case: \(testCase.name)"))
        #expect(vm.reference.bookUSFM == testCase.referenceBook, Comment("Case: \(testCase.name)"))
        #expect(vm.reference.chapter == testCase.referenceChapter, Comment("Case: \(testCase.name)"))

        vm.goToNextChapter()

        #expect(
            vm.reference == BibleReference(
                versionId: Self.versionId,
                bookUSFM: testCase.expectedBook,
                chapter: testCase.expectedChapter
            ),
            Comment("Case: \(testCase.name)")
        )
        #expect(vm.showBookIntro == testCase.expectedShowBookIntro, Comment("Case: \(testCase.name)"))
        assertNavigationSideEffects(on: vm)
    }

    @Test(arguments: previousChapterCases)
    func goToPreviousChapterTransitionsCorrectly(_ testCase: PreviousChapterCase) {
        let vm = makeViewModel(
            books: testCase.books,
            referenceBook: testCase.referenceBook,
            referenceChapter: testCase.referenceChapter,
            showBookIntro: testCase.showBookIntro
        )
        let expectedBookIds = testCase.books.map(\.id)
        let actualBookIds = vm.version?.books?.compactMap { $0.id } ?? []
        #expect(actualBookIds == expectedBookIds, Comment("Case: \(testCase.name)"))
        #expect(vm.reference.bookUSFM == testCase.referenceBook, Comment("Case: \(testCase.name)"))
        #expect(vm.reference.chapter == testCase.referenceChapter, Comment("Case: \(testCase.name)"))

        vm.goToPreviousChapter()

        #expect(
            vm.reference == BibleReference(
                versionId: Self.versionId,
                bookUSFM: testCase.expectedBook,
                chapter: testCase.expectedChapter
            ),
            Comment("Case: \(testCase.name)")
        )
        #expect(vm.showBookIntro == testCase.expectedShowBookIntro, Comment("Case: \(testCase.name)"))
        assertNavigationSideEffects(on: vm)
    }

    private func assertNavigationSideEffects(on vm: BibleReaderViewModel) {
        #expect(vm.isChangingChapter == true)
        #expect(vm.lastScrollOffset == 0)
        #expect(vm.scrollToTop == true)
        #expect(vm.selectedVerses.isEmpty)
        #expect(vm.showingVerseActionsDrawer == false)
    }

    private func makeViewModel(
        books: [BookFixture],
        referenceBook: String,
        referenceChapter: Int,
        showBookIntro: Bool
    ) -> BibleReaderViewModel {
        let reference = BibleReference(versionId: Self.versionId, bookUSFM: referenceBook, chapter: referenceChapter)
        let vm = BibleReaderViewModel(reference: reference)
        let selectedReference = BibleReference(versionId: Self.versionId, bookUSFM: referenceBook, chapter: referenceChapter, verse: 1)
        vm.versionsViewModel.switchToVersion(makeVersion(with: books))
        vm.showBookIntro = showBookIntro
        vm.isChangingChapter = false
        vm.lastScrollOffset = 321
        vm.scrollToTop = false
        vm.selectedVerses = [selectedReference]
        vm.showingVerseActionsDrawer = true
        return vm
    }

    private func makeVersion(with books: [BookFixture]) -> BibleVersion {
        BibleVersion(
            id: Self.versionId,
            abbreviation: "TEST",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "TST",
            localizedTitle: "Test Version",
            readerFooter: nil,
            readerFooterUrl: nil,
            title: "Test Version",
            organizationId: nil,
            bookCodes: books.map(\.id),
            books: books.map(makeBook(from:)),
            textDirection: "ltr"
        )
    }

    private func makeBook(from fixture: BookFixture) -> BibleBook {
        BibleBook(
            id: fixture.id,
            title: fixture.id,
            fullTitle: fixture.id,
            abbreviation: fixture.id,
            canon: "ot",
            chapters: makeChapters(bookId: fixture.id, chapterCount: fixture.chapterCount),
            intro: fixture.hasIntro ? BibleBookIntro(id: "\(fixture.id).intro", passageId: nil, title: "Intro") : nil
        )
    }

    private func makeChapters(bookId: String, chapterCount: Int) -> [BibleChapter] {
        (1...chapterCount).map { chapter in
            BibleChapter(id: "\(bookId).\(chapter)", passageId: nil, title: "\(chapter)", verses: nil)
        }
    }
}
