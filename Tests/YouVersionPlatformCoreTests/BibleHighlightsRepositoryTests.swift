import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - Mock API

@MainActor
class MockBibleHighlightsAPI: BibleHighlightsAPIProtocol {
    var createHighlightCallCount = 0
    var getHighlightsCallCount = 0
    var updateHighlightCallCount = 0
    var deleteHighlightCallCount = 0
    
    var shouldThrowError = false
    var mockCreateHighlightResult = true
    var mockGetHighlightsResult: [HighlightResponse] = []
    var mockUpdateHighlightResult = true
    var mockDeleteHighlightResult = true
    
    func reset() {
        createHighlightCallCount = 0
        getHighlightsCallCount = 0
        updateHighlightCallCount = 0
        deleteHighlightCallCount = 0
        shouldThrowError = false
        mockCreateHighlightResult = true
        mockGetHighlightsResult = []
        mockUpdateHighlightResult = true
        mockDeleteHighlightResult = true
    }
    
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

// MARK: - Tests

@MainActor
struct BibleHighlightsRepositoryTests {
    
    // MARK: - Test Setup and Teardown
    
    func setUp() -> MockBibleHighlightsAPI {
        let mockAPI = MockBibleHighlightsAPI()
        mockAPI.reset()
        return mockAPI
    }
    
    // MARK: - Test Highlights Fetching
    
    @Test
    func testHighlightsForReferences() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API response
        let mockResponse = [
            HighlightResponse(bibleId: 1, passageId: "GEN.1.1", color: "FF0000"),
            HighlightResponse(bibleId: 1, passageId: "GEN.1.2", color: "00FF00")
        ]
        mockAPI.mockGetHighlightsResult = mockResponse
        
        let references = [BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)]
        let result = try await repository.highlights(for: references)
        
        #expect(mockAPI.getHighlightsCallCount == 1)
        #expect(result.count == 1)
        #expect(result["1_GEN_1"]?.count == 2)
        #expect(result["1_GEN_1"]?.first?.reference.versionId == 1)
        #expect(result["1_GEN_1"]?.first?.reference.bookUSFM == "GEN")
        #expect(result["1_GEN_1"]?.first?.reference.chapter == 1)
        #expect(result["1_GEN_1"]?.first?.reference.verseStart == 1)
        #expect(result["1_GEN_1"]?.first?.color == "#FF0000")
    }
    
    @Test
    func testHighlightsForMultipleReferences() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API response
        let mockResponse = [
            HighlightResponse(bibleId: 1, passageId: "GEN.1.1", color: "FF0000"),
            HighlightResponse(bibleId: 1, passageId: "GEN.2.1", color: "00FF00")
        ]
        mockAPI.mockGetHighlightsResult = mockResponse
        
        let references = [
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1),
            BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 2)
        ]
        let result = try await repository.highlights(for: references)
        
        #expect(mockAPI.getHighlightsCallCount == 2)
        #expect(result.count == 2)
        #expect(result["1_GEN_1"]?.count == 2)
        #expect(result["1_GEN_2"]?.count == 2)
    }
    
    @Test
    func testHighlightsHandlesEmptyResponse() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock empty API response
        mockAPI.mockGetHighlightsResult = []
        
        let references = [BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)]
        let result = try await repository.highlights(for: references)
        
        #expect(mockAPI.getHighlightsCallCount == 1)
        #expect(result.count == 1)
        #expect(result["1_GEN_1"]?.isEmpty == true)
    }
    
    @Test
    func testHighlightsHandlesError() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API error
        mockAPI.shouldThrowError = true
        
        let references = [BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)]
        let result = try await repository.highlights(for: references)
        
        #expect(mockAPI.getHighlightsCallCount == 1)
        #expect(result.count == 1)
        #expect(result["1_GEN_1"]?.isEmpty == true)
    }
    
    // MARK: - Test Operation Processing
    
    @Test
    func testSaveOperationsAdd() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.createHighlightCallCount == 1)
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }
    
    @Test
    func testSaveOperationsRemove() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: nil, operationType: .remove)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.deleteHighlightCallCount == 1)
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }
    
    @Test
    func testSaveOperationsUpdate() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#00FF00", operationType: .update)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.updateHighlightCallCount == 1)
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }
    
    @Test
    func testSaveOperationsMultiple() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference1 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let reference2 = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 2)
        
        let operation1 = PendingHighlightOperation(references: [reference1], color: "#FF0000", operationType: .add)
        let operation2 = PendingHighlightOperation(references: [reference2], color: nil, operationType: .remove)
        
        let result = try await repository.saveOperations([operation1, operation2])
        
        #expect(mockAPI.createHighlightCallCount == 1)
        #expect(mockAPI.deleteHighlightCallCount == 1)
        #expect(result.count == 2)
        #expect(result[operation1.id] == true)
        #expect(result[operation2.id] == true)
    }
    
    @Test
    func testSaveOperationsHandlesError() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API error
        mockAPI.shouldThrowError = true
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.createHighlightCallCount == 1)
        #expect(result.count == 1)
        #expect(result[operation.id] == false)
    }
    
    @Test
    func testSaveOperationsAddWithoutColor() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: nil, operationType: .add)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.createHighlightCallCount == 0)
        #expect(result.count == 1)
        #expect(result[operation.id] == false)
    }
    
    @Test
    func testSaveOperationsUpdateWithoutColor() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: nil, operationType: .update)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.updateHighlightCallCount == 0)
        #expect(result.count == 1)
        #expect(result[operation.id] == false)
    }
    
    // MARK: - Test Queue Management
    
    @Test
    func testQueueOperation() {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        #expect(repository.pendingOperationCount == 0)
        
        repository.queueOperation(operation)
        
        #expect(repository.pendingOperationCount == 1)
    }
    
    @Test
    func testQueueOperationMaintainsOrder() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        
        // Create operations with different timestamps
        let operation1 = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        // Simulate time passing
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        let operation2 = PendingHighlightOperation(references: [reference], color: "#00FF00", operationType: .update)
        
        repository.queueOperation(operation2)
        repository.queueOperation(operation1)
        
        #expect(repository.pendingOperationCount == 2)
    }
    
    @Test
    func testProcessQueue() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        
        #expect(repository.pendingOperationCount == 1)
        
        await repository.processQueue()
        
        #expect(mockAPI.createHighlightCallCount == 1)
        #expect(repository.pendingOperationCount == 0)
    }
    
    @Test
    func testProcessQueueHandlesFailure() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API failure
        mockAPI.mockCreateHighlightResult = false
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        
        #expect(repository.pendingOperationCount == 1)
        
        await repository.processQueue()
        
        // The operation will be retried automatically, so we expect at least 1 call
        #expect(mockAPI.createHighlightCallCount >= 1)
        #expect(repository.pendingOperationCount == 1) // Should be re-queued
        #expect(repository.failedOperationCount == 1)
    }
    
    @Test
    func testProcessQueueHandlesError() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API error
        mockAPI.shouldThrowError = true
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        
        #expect(repository.pendingOperationCount == 1)
        
        await repository.processQueue()
        
        // The operation will be retried automatically, so we expect at least 1 call
        #expect(mockAPI.createHighlightCallCount >= 1)
        #expect(repository.pendingOperationCount == 1) // Should be re-queued
        #expect(repository.failedOperationCount == 1)
    }
    
    // MARK: - Test Operation Results
    
    @Test
    func testGetOperationResult() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        await repository.processQueue()
        
        let result = repository.getOperationResult(for: operation.id)
        
        #expect(result != nil)
        #expect(result?.operationId == operation.id)
        #expect(result?.success == true)
        #expect(result?.retryCount == 0)
    }
    
    @Test
    func testClearOperationResults() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        await repository.processQueue()
        
        let result = repository.getOperationResult(for: operation.id)
        #expect(result != nil)
        
        repository.clearOperationResults()
        
        let clearedResult = repository.getOperationResult(for: operation.id)
        #expect(clearedResult == nil)
    }
    
    @Test
    func testRetryFailedOperations() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        // Mock API failure
        mockAPI.mockCreateHighlightResult = false
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        await repository.processQueue()
        
        #expect(repository.failedOperationCount == 1)
        
        // Reset mock to succeed
        mockAPI.mockCreateHighlightResult = true
        
        await repository.retryFailedOperations()
        
        // The operation will be retried, so we expect at least 2 calls (original + retry)
        #expect(mockAPI.createHighlightCallCount >= 2)
        #expect(repository.pendingOperationCount == 0)
    }
} 
