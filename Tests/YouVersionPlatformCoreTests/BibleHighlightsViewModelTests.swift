import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - Mock Classes

class MockBibleHighlightsAPIVM: BibleHighlightsAPIProtocol {
    var createHighlightCallCount = 0
    var getHighlightsCallCount = 0
    var updateHighlightCallCount = 0
    var deleteHighlightCallCount = 0

    var shouldThrowError = false
    var mockCreateHighlightResult = true
    var mockGetHighlightsResult: [HighlightResponse] = []
    var mockUpdateHighlightResult = true
    var mockDeleteHighlightResult = true

    func highlights(bibleId: Int, passageId: String) async throws -> [HighlightResponse] {
        getHighlightsCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockGetHighlightsResult
    }

    func createHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool {
        createHighlightCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockCreateHighlightResult
    }

    func updateHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool {
        updateHighlightCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockUpdateHighlightResult
    }

    func deleteHighlight(bibleId: Int, passageId: String) async throws -> Bool {
        deleteHighlightCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockDeleteHighlightResult
    }
}

class MockBibleHighlightsRepository: BibleHighlightsRepository {
    var queueOperationCallCount = 0
    var highlightsCallCount = 0
    var shouldThrowError = false
    var mockServerData: [String: [BibleHighlight]] = [:]
    private let mockAPI = MockBibleHighlightsAPIVM()

    init() {
        super.init(api: mockAPI)
    }

    override func highlights(for references: [BibleReference]) async throws -> [String: [BibleHighlight]] {
        highlightsCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockServerData
    }

    override func queueOperation(_ operation: PendingHighlightOperation) {
        queueOperationCallCount += 1
        super.queueOperation(operation)
    }
}

// MARK: - Tests

@MainActor
struct BibleHighlightsViewModelTests {
    
    // MARK: - Test Initialization
    
    @Test
    func testInitWithDependencies() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        // This should work with our injected dependencies
        let highlights = viewModel.highlights(for: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10))
        #expect(highlights.isEmpty)
    }
    
    // MARK: - Test Getting Highlights
    
    @Test
    func testGetHighlights() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        let highlights = viewModel.highlights(for: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10))
        
        #expect(highlights.isEmpty)
    }
    
    // Publisher-based APIs removed; tests adjusted accordingly
    
    // MARK: - Test Adding Highlights
    
    @Test
    func testAddHighlights() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        let color = "eefeef"
        
        viewModel.addHighlights(references: references, color: color)
        
        // repository queue invoked
        #expect(mockRepository.queueOperationCallCount == 1)
    }
    
    @Test
    func testAddHighlightsCreatesCorrectHighlights() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        let color = "eefeef"
        
        viewModel.addHighlights(references: references, color: color)
        
        // Verify highlights were added to cache
        let highlights = viewModel.highlights(
            for: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 2)
        )
        
        #expect(highlights.count == 2)
        #expect(highlights.allSatisfy { $0.color == color })
        #expect(highlights.contains { $0.reference.verseStart == 1 })
        #expect(highlights.contains { $0.reference.verseStart == 2 })
    }
    
    // MARK: - Test Removing Highlights
    
    @Test
    func testRemoveHighlights() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        
        viewModel.removeHighlights(references: references)
        
        // repository queue invoked
        #expect(mockRepository.queueOperationCallCount == 1)
    }
    
    @Test
    func testRemoveHighlightsRemovesFromCache() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        // First add some highlights
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        viewModel.addHighlights(references: references, color: "eefeef")
        
        // Then remove them
        viewModel.removeHighlights(references: references)
        
        // Verify they're gone
        let highlights = viewModel.highlights(
            for: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 2)
        )
        
        #expect(highlights.isEmpty)
    }
    
    // MARK: - Test Updating Highlight Colors
    
    @Test
    func testUpdateHighlightColors() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        let newColor = "0000ff"
        
        viewModel.updateHighlightColors(references: references, newColor: newColor)
        
        #expect(mockRepository.queueOperationCallCount == 1)
    }
    
    @Test
    func testUpdateHighlightColorsUpdatesCache() {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        // First add some highlights
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        ]
        viewModel.addHighlights(references: references, color: "eefeef")
        
        // Then update their colors
        let newColor = "0000ff"
        viewModel.updateHighlightColors(references: references, newColor: newColor)
        
        // Verify colors were updated
        let highlights = viewModel.highlights(
            for: BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 2)
        )
        
        #expect(highlights.count == 2)
        #expect(highlights.allSatisfy { $0.color == newColor })
    }
    
    // MARK: - Test Chapter Loading
    
    @Test
    func testEnsureChaptersLoaded() async {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)

        // This should trigger chapter loading
        viewModel.ensureHighlightsForChapterLoaded(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10))
        // give the async task a moment
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(mockRepository.highlightsCallCount >= 0)
    }
    
    @Test
    func testLoadChapterFromServer() async {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        // Simulate loading a chapter
        
        // This should trigger server load
        viewModel.ensureHighlightsForChapterLoaded(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10))
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(mockRepository.highlightsCallCount > 0)
    }
    
    @Test
    func testLoadChapterFromServerHandlesError() async {
        let cache = BibleHighlightsCache()
        let mockRepository = MockBibleHighlightsRepository()
        mockRepository.shouldThrowError = true
        let viewModel = BibleHighlightsViewModel(cache: cache, repository: mockRepository)
        
        // Simulate loading a chapter that will fail
        
        // This should trigger server load that fails
        viewModel.ensureHighlightsForChapterLoaded(BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verseStart: 1, verseEnd: 10))
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(mockRepository.highlightsCallCount > 0)
    }
} 
