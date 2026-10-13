import Testing
@testable import YouVersionPlatformReader

@Suite struct ReaderNavigationLayoutTests {
    @Test func defaultsToBottomWithAudioFirst() {
        let layout = ReaderNavigationLayout(options: BibleReaderNavigationOptions(), tabLocation: .none, hasVerticalToolbar: false)
        #expect(layout.placement == .bottomBar)
        #expect(layout.primaryAction == .audio)
        #expect(layout.upperAction == .search)
        #expect(layout.menuActions.isEmpty)
        #expect(!layout.usesSystemToolbar)
    }

    @Test func horizontalTabsOverridePreferredEdge() {
        let topTabs = ReaderNavigationLayout(options: BibleReaderNavigationOptions(placement: .topBar),
                                             tabLocation: .top, hasVerticalToolbar: false)
        let bottomTabs = ReaderNavigationLayout(options: BibleReaderNavigationOptions(),
                                                tabLocation: .bottom, hasVerticalToolbar: false)
        #expect(topTabs.placement == .bottomBar)
        #expect(bottomTabs.placement == .topBar)
        #expect(bottomTabs.primaryAction == nil)
        #expect(bottomTabs.upperAction == .search)
        #expect(bottomTabs.menuActions == [.audio])
    }

    @Test func onlyVerticalToolbarEnablesNativeControls() {
        let layout = ReaderNavigationLayout(options: BibleReaderNavigationOptions(), tabLocation: .bottom, hasVerticalToolbar: true)
        #expect(layout.usesSystemToolbar)
        #expect(layout.upperAction == nil)
        #expect(layout.menuActions == [.audio, .search])
        #expect(layout.placement == .topBar)
    }

    @Test func otherTabPlacementHonorsPreference() {
        let layout = ReaderNavigationLayout(options: BibleReaderNavigationOptions(placement: .topBar),
                                            tabLocation: .other, hasVerticalToolbar: false)
        #expect(layout.placement == .topBar)
    }

    @Test func actionOrderControlsPriorityWithoutDuplicates() {
        let layout = ReaderNavigationLayout(options: BibleReaderNavigationOptions(actions: [.search, .search, .audio]),
                                            tabLocation: .none, hasVerticalToolbar: false)
        #expect(layout.primaryAction == .search)
        #expect(layout.upperAction == .audio)
        #expect(layout.actions == [.search, .audio])
    }

    @Test func supportsNoActions() {
        let layout = ReaderNavigationLayout(options: BibleReaderNavigationOptions(actions: []),
                                            tabLocation: .none, hasVerticalToolbar: false)
        #expect(layout.primaryAction == nil)
        #expect(layout.upperAction == nil)
        #expect(layout.menuActions.isEmpty)
    }
}
