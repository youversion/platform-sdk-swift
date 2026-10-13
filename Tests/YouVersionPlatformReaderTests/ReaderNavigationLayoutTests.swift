import Testing
@testable import YouVersionPlatformReader

@Suite struct ReaderNavigationLayoutTests {
    @Test func defaultsToBottomWithSearchBesidePickers() {
        let layout = ReaderNavigationLayout(tabLocation: .none, hasVerticalToolbar: false)
        #expect(layout.placement == .bottomBar)
        #expect(layout.primaryAction == .search)
        #expect(layout.upperAction == nil)
        #expect(layout.menuActions.isEmpty)
        #expect(!layout.usesSystemToolbar)
    }

    @Test func horizontalTabsOverridePreferredEdge() {
        let topTabs = ReaderNavigationLayout(preferredPlacement: .topBar,
                                             tabLocation: .top, hasVerticalToolbar: false)
        let bottomTabs = ReaderNavigationLayout(tabLocation: .bottom, hasVerticalToolbar: false)
        #expect(topTabs.placement == .bottomBar)
        #expect(bottomTabs.placement == .topBar)
        #expect(bottomTabs.primaryAction == nil)
        #expect(bottomTabs.upperAction == .search)
        #expect(bottomTabs.menuActions.isEmpty)
    }

    @Test func onlyVerticalToolbarEnablesNativeControls() {
        let layout = ReaderNavigationLayout(usesHostNavigationToolbar: true,
                                            tabLocation: .bottom, hasVerticalToolbar: true)
        #expect(layout.usesSystemToolbar)
        #expect(layout.upperAction == nil)
        #expect(layout.menuActions == [.search])
        #expect(layout.placement == .topBar)
    }

    @Test(arguments: [false, true], [false, true])
    func nativeControlsRequireHostConsentAndVerticalPlacement(hostConsent: Bool, verticalPlacement: Bool) {
        let layout = ReaderNavigationLayout(
            usesHostNavigationToolbar: hostConsent,
            tabLocation: .bottom,
            hasVerticalToolbar: verticalPlacement
        )
        #expect(layout.usesSystemToolbar == (hostConsent && verticalPlacement))
        #expect(layout.placement == .topBar)
        if !layout.usesSystemToolbar {
            #expect(layout.upperAction == .search)
            #expect(layout.menuActions.isEmpty)
        }
    }

    @Test func verticalPlacementKeepsCustomControlsByDefault() {
        let layout = ReaderNavigationLayout(tabLocation: .none, hasVerticalToolbar: true)
        #expect(!layout.usesSystemToolbar)
        #expect(layout.primaryAction == .search)
    }

    @Test func otherTabPlacementHonorsPreference() {
        let layout = ReaderNavigationLayout(preferredPlacement: .topBar,
                                            tabLocation: .other, hasVerticalToolbar: false)
        #expect(layout.placement == .topBar)
    }

}
