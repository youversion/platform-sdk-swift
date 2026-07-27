import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - Mock API

@MainActor
final class MockBibleHighlightsAPI: BibleHighlightsAPIProtocol {
    var createHighlightCallCount = 0
    var getHighlightsCallCount = 0
    var updateHighlightCallCount = 0
    var deleteHighlightCallCount = 0
    var createHighlightCalls: [(bibleId: Int, passageId: String, color: String)] = []
    var updateHighlightCalls: [(bibleId: Int, passageId: String, color: String)] = []
    var deleteHighlightCalls: [(bibleId: Int, passageId: String)] = []

    var shouldThrowError = false
    var shouldSuspendCreateHighlight = false
    var mockCreateHighlightResult = true
    var mockCreateHighlightResults: [Bool] = []
    var mockGetHighlightsResult: [HighlightResponse] = []
    var mockUpdateHighlightResult = true
    var mockDeleteHighlightResult = true
    private var createHighlightContinuation: CheckedContinuation<Void, Never>?
    
    func reset() {
        createHighlightCallCount = 0
        getHighlightsCallCount = 0
        updateHighlightCallCount = 0
        deleteHighlightCallCount = 0
        createHighlightCalls = []
        updateHighlightCalls = []
        deleteHighlightCalls = []
        shouldThrowError = false
        shouldSuspendCreateHighlight = false
        mockCreateHighlightResult = true
        mockCreateHighlightResults = []
        mockGetHighlightsResult = []
        mockUpdateHighlightResult = true
        mockDeleteHighlightResult = true
    }

    func waitForCreateHighlightToStart() async {
        while shouldSuspendCreateHighlight && createHighlightContinuation == nil {
            await Task.yield()
        }
    }

    func resumeCreateHighlight() {
        shouldSuspendCreateHighlight = false
        createHighlightContinuation?.resume()
        createHighlightContinuation = nil
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
        createHighlightCalls.append((bibleId, passageId, color))

        if shouldSuspendCreateHighlight {
            await withCheckedContinuation { continuation in
                createHighlightContinuation = continuation
            }
        }
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        if !mockCreateHighlightResults.isEmpty {
            return mockCreateHighlightResults.removeFirst()
        }
        return mockCreateHighlightResult
    }
    
    func updateHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool {
        updateHighlightCallCount += 1
        updateHighlightCalls.append((bibleId, passageId, color))
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        return mockUpdateHighlightResult
    }
    
    func deleteHighlight(bibleId: Int, passageId: String) async throws -> Bool {
        deleteHighlightCallCount += 1
        deleteHighlightCalls.append((bibleId, passageId))
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        return mockDeleteHighlightResult
    }
}

@MainActor
final class ThrowingBibleHighlightsRepository: BibleHighlightsRepository {
    override func saveOperations(_ operations: [PendingHighlightOperation]) async throws -> [UUID: Bool] {
        throw NSError(domain: "TestError", code: 1)
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
    
    private func reference(verse: Int = 1) -> BibleReference {
        BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: verse)
    }

    private func operation(
        color: String? = "#FF0000",
        operationType: HighlightOperationType = .add,
        verse: Int = 1
    ) -> PendingHighlightOperation {
        PendingHighlightOperation(references: [reference(verse: verse)], color: color, operationType: operationType)
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

    @Test
    func testHighlightsIgnoresInvalidPassageIDs() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        mockAPI.mockGetHighlightsResult = [
            HighlightResponse(bibleId: 1, passageId: "GEN.1", color: "FF0000"),
            HighlightResponse(bibleId: 1, passageId: "GEN.chapter.1", color: "00FF00"),
            HighlightResponse(bibleId: 1, passageId: "GEN.1.verse", color: "0000FF"),
            HighlightResponse(bibleId: 1, passageId: "GEN.1.2", color: "FFFF00")
        ]

        let references = [BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)]
        let result = try await repository.highlights(for: references)

        #expect(result["1_GEN_1"]?.count == 1)
        #expect(result["1_GEN_1"]?.first?.reference.verseStart == 2)
        #expect(result["1_GEN_1"]?.first?.color == "#FFFF00")
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
        #expect(mockAPI.createHighlightCalls.first?.bibleId == 1)
        #expect(mockAPI.createHighlightCalls.first?.passageId == "GEN.1.1")
        #expect(mockAPI.createHighlightCalls.first?.color == "FF0000")
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }

    @Test
    func testSaveOperationsAddDefaultsToFirstVerse() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        let reference = BibleReference(versionId: 42, bookUSFM: "JHN", chapter: 3)
        let operation = PendingHighlightOperation(references: [reference], color: "00FF00", operationType: .add)

        let result = try await repository.saveOperations([operation])

        #expect(mockAPI.createHighlightCalls.first?.bibleId == 42)
        #expect(mockAPI.createHighlightCalls.first?.passageId == "JHN.3.1")
        #expect(mockAPI.createHighlightCalls.first?.color == "00FF00")
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
        #expect(mockAPI.deleteHighlightCalls.first?.bibleId == 1)
        #expect(mockAPI.deleteHighlightCalls.first?.passageId == "GEN.1.1")
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }

    @Test
    func testSaveOperationsRemoveHandlesFailure() async throws {
        let mockAPI = setUp()
        mockAPI.mockDeleteHighlightResult = false
        let repository = BibleHighlightsRepository(api: mockAPI)
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: nil, operationType: .remove)

        let result = try await repository.saveOperations([operation])

        #expect(mockAPI.deleteHighlightCallCount == 1)
        #expect(result[operation.id] == false)
    }
    
    @Test
    func testSaveOperationsUpdate() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#00FF00", operationType: .update)
        
        let result = try await repository.saveOperations([operation])
        
        #expect(mockAPI.updateHighlightCallCount == 1)
        #expect(mockAPI.updateHighlightCalls.first?.bibleId == 1)
        #expect(mockAPI.updateHighlightCalls.first?.passageId == "GEN.1.1")
        #expect(mockAPI.updateHighlightCalls.first?.color == "00FF00")
        #expect(result.count == 1)
        #expect(result[operation.id] == true)
    }

    @Test
    func testSaveOperationsUpdateHandlesThrownError() async throws {
        let mockAPI = setUp()
        mockAPI.shouldThrowError = true
        let repository = BibleHighlightsRepository(api: mockAPI)
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#00FF00", operationType: .update)

        let result = try await repository.saveOperations([operation])

        #expect(mockAPI.updateHighlightCallCount == 1)
        #expect(result[operation.id] == false)
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
    
    @Test
    func testSaveOperationsRemoveHandlesError() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        mockAPI.shouldThrowError = true
        let operation = operation(color: nil, operationType: .remove)

        let result = try await repository.saveOperations([operation])

        #expect(mockAPI.deleteHighlightCallCount == 1)
        #expect(result[operation.id] == false)
    }

    @Test
    func testSaveOperationsUpdateHandlesFailedResult() async throws {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        mockAPI.mockUpdateHighlightResult = false
        let operation = operation(operationType: .update)

        let result = try await repository.saveOperations([operation])

        #expect(mockAPI.updateHighlightCallCount == 1)
        #expect(result[operation.id] == false)
    }

    // MARK: - Test Queue Management
    
    @Test
    func testQueueOperation() {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        #expect(!repository.hasPendingOperations)
        
        repository.queueOperation(operation)
        
        #expect(repository.hasPendingOperations)
    }
    
    @Test
    func testMultipleQueueOperationsArePending() {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI, shouldProcessQueueAutomatically: false)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation1 = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        let operation2 = PendingHighlightOperation(references: [reference], color: "#00FF00", operationType: .update)
        
        repository.queueOperation(operation2)
        repository.queueOperation(operation1)
        
        #expect(repository.hasPendingOperations)
        #expect(repository.pendingOperationCount == 2)
    }

    @Test
    func testPendingOperationCountExcludesProcessingOperation() async {
        let mockAPI = setUp()
        mockAPI.shouldSuspendCreateHighlight = true
        let repository = BibleHighlightsRepository(api: mockAPI)
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let processingOperation = PendingHighlightOperation(
            references: [reference],
            color: "#FF0000",
            operationType: .add
        )
        let pendingOperation = PendingHighlightOperation(
            references: [reference],
            color: "#00FF00",
            operationType: .update
        )

        repository.queueOperation(processingOperation)
        await mockAPI.waitForCreateHighlightToStart()
        repository.queueOperation(pendingOperation)

        #expect(repository.pendingOperationCount == 1)

        mockAPI.resumeCreateHighlight()
        while repository.hasPendingOperations {
            await Task.yield()
        }
    }

    @Test
    func testClearPendingOperations() {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)

        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let firstOperation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        let secondOperation = PendingHighlightOperation(references: [reference], color: nil, operationType: .remove)

        repository.queueOperation(firstOperation)
        repository.queueOperation(secondOperation)

        #expect(repository.hasPendingOperations)

        repository.clearPendingOperations()

        #expect(!repository.hasPendingOperations)
    }

    @Test
    func testClearPendingOperationsDoesNotRequeueProcessingOperation() async {
        let mockAPI = setUp()
        mockAPI.shouldSuspendCreateHighlight = true
        mockAPI.mockCreateHighlightResult = false
        let repository = BibleHighlightsRepository(api: mockAPI)

        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)

        repository.queueOperation(operation)
        await mockAPI.waitForCreateHighlightToStart()

        repository.clearPendingOperations()

        #expect(repository.hasPendingOperations)

        mockAPI.resumeCreateHighlight()

        while repository.hasPendingOperations {
            await Task.yield()
        }

        #expect(repository.failedOperationCount == 0)
    }

    @Test
    func testHasPendingOperationsWhileQueueIsProcessing() async {
        let mockAPI = setUp()
        mockAPI.shouldSuspendCreateHighlight = true
        let repository = BibleHighlightsRepository(api: mockAPI)

        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)

        repository.queueOperation(operation)
        await mockAPI.waitForCreateHighlightToStart()

        #expect(repository.hasPendingOperations)

        mockAPI.resumeCreateHighlight()

        while repository.hasPendingOperations {
            await Task.yield()
        }

        #expect(mockAPI.createHighlightCallCount == 1)
    }
    
    @Test
    func testProcessQueue() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI)
        
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)
        
        repository.queueOperation(operation)
        
        #expect(repository.hasPendingOperations)
        
        await repository.processQueue()
        
        #expect(mockAPI.createHighlightCallCount == 1)
        #expect(!repository.hasPendingOperations)
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
        
        #expect(repository.hasPendingOperations)
        
        await repository.processQueue()
        
        // The operation will be retried automatically, so we expect at least 1 call
        #expect(mockAPI.createHighlightCallCount >= 1)
        #expect(repository.hasPendingOperations)
        #expect(repository.failedOperationCount == 1)

        mockAPI.mockCreateHighlightResult = true
        await repository.retryFailedOperations()
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
        
        #expect(repository.hasPendingOperations)
        
        await repository.processQueue()
        
        // The operation will be retried automatically, so we expect at least 1 call
        #expect(mockAPI.createHighlightCallCount >= 1)
        #expect(repository.hasPendingOperations)
        #expect(repository.failedOperationCount == 1)

        mockAPI.shouldThrowError = false
        await repository.retryFailedOperations()
    }

    @Test
    func testProcessQueueHandlesUnexpectedSaveOperationsError() async {
        let mockAPI = setUp()
        let repository = ThrowingBibleHighlightsRepository(
            api: mockAPI,
            shouldProcessQueueAutomatically: false
        )
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)

        repository.queueOperation(operation)
        await repository.processQueue()

        let result = repository.getOperationResult(for: operation.id)
        #expect(result?.success == false)
        #expect(result?.error != nil)
        #expect(result?.retryCount == 1)
        #expect(repository.pendingOperationCount == 1)
    }

    @Test
    func testFailedOperationsAreRetriedAutomatically() async {
        let mockAPI = setUp()
        mockAPI.mockCreateHighlightResults = [false, true]
        let repository = BibleHighlightsRepository(api: mockAPI, retryDelayNanoseconds: 0)

        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1, verse: 1)
        let operation = PendingHighlightOperation(references: [reference], color: "#FF0000", operationType: .add)

        repository.queueOperation(operation)

        while mockAPI.createHighlightCallCount < 2 {
            await Task.yield()
        }
        while repository.hasPendingOperations {
            await Task.yield()
        }

        #expect(mockAPI.createHighlightCallCount == 2)
        #expect(!repository.hasPendingOperations)
    }
    
    @Test
    func testProcessQueueRequeuesFailedRemoveOperation() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI, shouldProcessQueueAutomatically: false)
        mockAPI.mockDeleteHighlightResult = false
        let operation = operation(color: nil, operationType: .remove)

        repository.queueOperation(operation)
        await repository.processQueue()

        let result = repository.getOperationResult(for: operation.id)
        #expect(mockAPI.deleteHighlightCallCount == 1)
        #expect(repository.pendingOperationCount == 1)
        #expect(repository.failedOperationCount == 1)
        #expect(result?.success == false)
        #expect(result?.error != nil)
    }

    @Test
    func testProcessQueueRequeuesFailedUpdateOperation() async {
        let mockAPI = setUp()
        let repository = BibleHighlightsRepository(api: mockAPI, shouldProcessQueueAutomatically: false)
        mockAPI.mockUpdateHighlightResult = false
        let operation = operation(operationType: .update)

        repository.queueOperation(operation)
        await repository.processQueue()

        let result = repository.getOperationResult(for: operation.id)
        #expect(mockAPI.updateHighlightCallCount == 1)
        #expect(repository.pendingOperationCount == 1)
        #expect(repository.failedOperationCount == 1)
        #expect(result?.success == false)
        #expect(result?.error != nil)
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
        #expect(!repository.hasPendingOperations)
    }
}
