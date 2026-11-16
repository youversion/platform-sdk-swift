import Testing
@testable import YouVersionPlatformReader

struct ChapterCompletionArmingTests {
    @Test
    func aOneScreenChapterCountsOnceWhenOpened() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.onLeadingEdge(0)
        #expect(arming.isArmed)

        arming.consume()
        arming.onLeadingEdge(0)
        #expect(arming.isArmed == false)
    }

    @Test
    func aOneScreenChapterStaysDisarmedHoweverOftenTheLayoutSettles() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.consume()
        for _ in 0..<5 {
            arming.onLeadingEdge(0)
        }
        #expect(arming.isArmed == false)
    }

    @Test
    func aProgrammaticScrollDisarmsUntilTheTopIsSeenAgain() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.onProgrammaticScroll()
        #expect(arming.isArmed == false)

        arming.onLeadingEdge(0)
        #expect(arming.isArmed == false)

        arming.onLeadingEdge(-300)
        arming.onLeadingEdge(0)
        #expect(arming.isArmed)
    }

    @Test
    func aTallChapterOpenedAtItsTopIsStillArmedAtTheBottom() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.onLeadingEdge(-500)
        arming.onLeadingEdge(-2000)
        #expect(arming.isArmed)
    }

    @Test
    func aGenuineSecondPassCountsAgain() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.onLeadingEdge(-2000)
        arming.consume()
        #expect(arming.isArmed == false)

        arming.onLeadingEdge(-1000)
        arming.onLeadingEdge(0)
        #expect(arming.isArmed)
    }

    @Test
    func sittingAtTheBottomDoesNotReArmOnItsOwn() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.onLeadingEdge(-2000)
        arming.consume()
        for _ in 0..<5 {
            arming.onLeadingEdge(-2000)
        }
        #expect(arming.isArmed == false)
    }

    @Test
    func openingMidChapterIsNotArmedUntilTheTopHasBeenSeen() {
        var arming = ChapterCompletionArming(opensAtChapterTop: false)
        arming.onLeadingEdge(-800)
        #expect(arming.isArmed == false)

        arming.onLeadingEdge(0)
        #expect(arming.isArmed)
    }

    @Test
    func aOneScreenChapterOpenedMidWayNeverSelfArms() {
        var arming = ChapterCompletionArming(opensAtChapterTop: false)
        for _ in 0..<5 {
            arming.onLeadingEdge(0)
        }
        #expect(arming.isArmed == false)
    }

    @Test
    func resetArmsAChapterOpenedAtItsTop() {
        var arming = ChapterCompletionArming(opensAtChapterTop: true)
        arming.consume()
        arming.reset(opensAtChapterTop: true)
        #expect(arming.isArmed)
    }

    @Test
    func resetClearsAHalfFinishedPass() {
        var arming = ChapterCompletionArming(opensAtChapterTop: false)
        arming.onLeadingEdge(-800)
        arming.reset(opensAtChapterTop: false)
        arming.onLeadingEdge(0)
        #expect(arming.isArmed == false)
    }
}
