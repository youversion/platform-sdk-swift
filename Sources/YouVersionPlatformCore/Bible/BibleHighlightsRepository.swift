import Foundation

// MARK: - API Protocol for Dependency Injection

@MainActor
public protocol BibleHighlightsAPIProtocol {
    func highlights(bibleId: Int, passageId: String) async throws -> [HighlightResponse]
    func createHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool
    func updateHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool
    func deleteHighlight(bibleId: Int, passageId: String) async throws -> Bool
}

// MARK: - Default API Implementation

@MainActor
public struct BibleHighlightsAPI: BibleHighlightsAPIProtocol {
    public init() {}
    
    public func highlights(bibleId: Int, passageId: String) async throws -> [HighlightResponse] {
        try await YouVersionAPI.Highlights.getHighlights(bibleId: bibleId, passageId: passageId)
    }
    
    public func createHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool {
        try await YouVersionAPI.Highlights.createHighlight(bibleId: bibleId, passageId: passageId, color: color)
    }
    
    public func updateHighlight(bibleId: Int, passageId: String, color: String) async throws -> Bool {
        try await YouVersionAPI.Highlights.updateHighlight(bibleId: bibleId, passageId: passageId, color: color)
    }
    
    public func deleteHighlight(bibleId: Int, passageId: String) async throws -> Bool {
        try await YouVersionAPI.Highlights.deleteHighlight(bibleId: bibleId, passageId: passageId)
    }
}

// MARK: - Protocols for Dependency Injection

public protocol BibleHighlightsRepositoryProtocol {
    @MainActor func highlights(for references: [BibleReference]) async throws -> [String: [BibleHighlight]]
    @MainActor func queueOperation(_ operation: PendingHighlightOperation)
}

public struct OperationResult {
    public let operationId: UUID
    public let success: Bool
    public let error: Error?
    public let retryCount: Int
    
    public init(operationId: UUID, success: Bool, error: Error? = nil, retryCount: Int = 0) {
        self.operationId = operationId
        self.success = success
        self.error = error
        self.retryCount = retryCount
    }
}

@MainActor
public class BibleHighlightsRepository: BibleHighlightsRepositoryProtocol {
    
    // MARK: - Private Properties
    
    private let api: BibleHighlightsAPIProtocol
    private var pendingServerOperations: [PendingHighlightOperation] = []
    private var operationResults: [UUID: OperationResult] = [:]
    private var processingQueue = false
    
    // MARK: - Initialization
    
    public init(api: BibleHighlightsAPIProtocol = BibleHighlightsAPI()) {
        self.api = api
    }
    
    // MARK: - Public Methods
    
    public func highlights(for references: [BibleReference]) async throws -> [String: [BibleHighlight]] {
        var result: [String: [BibleHighlight]] = [:]

        for reference in references {
            let passageId = "\(reference.bookUSFM).\(reference.chapter)"
            let chapterKey = "\(reference.versionId)_\(reference.bookUSFM)_\(reference.chapter)"
            do {
                let apiHighlights = try await api.highlights(bibleId: reference.versionId, passageId: passageId)

                let bibleHighlights = apiHighlights.compactMap { apiHighlight in
                    convertToBibleHighlight(from: apiHighlight)
                }
                result[chapterKey] = bibleHighlights
            } catch {
                print("Failed to fetch highlights for chapter \(chapterKey): \(error)")
                result[chapterKey] = []
            }
        }

        return result
    }
    
    public func saveOperations(_ operations: [PendingHighlightOperation]) async throws -> [UUID: Bool] {
        var results: [UUID: Bool] = [:]
        
        for operation in operations {
            do {
                let success = try await processOperation(operation)
                results[operation.id] = success
            } catch {
                print("Failed to process operation \(operation.id): \(error)")
                results[operation.id] = false
            }
        }
        
        return results
    }
    
    // MARK: - Private Helper Methods
    
    func convertToBibleHighlight(from apiHighlight: HighlightResponse) -> BibleHighlight? {
        // Parse passageId to extract book, chapter, and verse
        // Expected format: "BOOK.CHAPTER.VERSE" (e.g., "JHN.5.1")
        let components = apiHighlight.passageId.split(separator: ".")
        guard components.count >= 3,
              let chapter = Int(components[1]),
              let verse = Int(components[2]) else {
            print("Invalid passage ID format: \(apiHighlight.passageId)")
            return nil
        }

        let book = String(components[0])
        let color = "#\(apiHighlight.color)" // Convert hex color to include #

        return BibleHighlight(
            BibleReference(
                versionId: apiHighlight.bibleId,
                bookUSFM: book,
                chapter: chapter,
                verse: verse
            ),
            color: color
        )
    }
    
    private func processOperation(_ operation: PendingHighlightOperation) async throws -> Bool {
        switch operation.operationType {
        case .add:
            return try await processAddOperation(operation)
        case .remove:
            return try await processRemoveOperation(operation)
        case .update:
            return try await processUpdateOperation(operation)
        }
    }
    
    private func processAddOperation(_ operation: PendingHighlightOperation) async throws -> Bool {
        guard let color = operation.color else {
            throw NSError(domain: "BibleHighlights", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Color is required for add operation"
            ])
        }
        
        var success = true
        for reference in operation.references {
            let passageId = "\(reference.bookUSFM).\(reference.chapter).\(reference.verseStart ?? 1)"
            let hexColor = color.hasPrefix("#") ? String(color.dropFirst()) : color
            
            do {
                let result = try await api.createHighlight(
                    bibleId: reference.versionId,
                    passageId: passageId,
                    color: hexColor
                )
                if !result {
                    success = false
                }
            } catch {
                print("Failed to create highlight for \(passageId): \(error)")
                success = false
            }
        }
        
        return success
    }
    
    private func processRemoveOperation(_ operation: PendingHighlightOperation) async throws -> Bool {
        var success = true
        for reference in operation.references {
            let passageId = "\(reference.bookUSFM).\(reference.chapter).\(reference.verseStart ?? 1)"
            
            do {
                let result = try await api.deleteHighlight(
                    bibleId: reference.versionId,
                    passageId: passageId
                )
                if !result {
                    success = false
                }
            } catch {
                print("Failed to delete highlight for \(passageId): \(error)")
                success = false
            }
        }
        
        return success
    }
    
    private func processUpdateOperation(_ operation: PendingHighlightOperation) async throws -> Bool {
        guard let color = operation.color else {
            throw NSError(domain: "BibleHighlights", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Color is required for update operation"
            ])
        }
        
        var success = true
        for reference in operation.references {
            let passageId = "\(reference.bookUSFM).\(reference.chapter).\(reference.verseStart ?? 1)"
            let hexColor = color.hasPrefix("#") ? String(color.dropFirst()) : color
            
            do {
                let result = try await api.updateHighlight(
                    bibleId: reference.versionId,
                    passageId: passageId,
                    color: hexColor
                )
                if !result {
                    success = false
                }
            } catch {
                print("Failed to update highlight for \(passageId): \(error)")
                success = false
            }
        }
        
        return success
    }
    
    // MARK: - Queue Management Methods
    
    public func queueOperation(_ operation: PendingHighlightOperation) {
        pendingServerOperations.append(operation)
        // Sort by timestamp to maintain order
        pendingServerOperations.sort { $0.timestamp < $1.timestamp }
        
        // Start processing if not already running
        if !processingQueue {
            Task {
                await processQueue()
            }
        }
    }
    
    public func processQueue() async {
        guard !processingQueue && !pendingServerOperations.isEmpty else {
            return
        }
        
        processingQueue = true
        defer { processingQueue = false }
        
        // Get current batch of operations
        let operationsToProcess = pendingServerOperations
        pendingServerOperations.removeAll()
        
        do {
            let results = try await saveOperations(operationsToProcess)
            
            // Update operation results
            for operation in operationsToProcess {
                let success = results[operation.id] ?? false
                let result = OperationResult(
                    operationId: operation.id,
                    success: success,
                    error: success ? nil : NSError(domain: "BibleHighlights", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server operation failed"]),
                    retryCount: 0
                )
                operationResults[operation.id] = result
                
                if !success {
                    // Re-queue failed operations
                    pendingServerOperations.append(operation)
                }
            }
            
            // If there are still pending operations (failed ones), try again
            if !pendingServerOperations.isEmpty {
                // swiftlint:disable:next common_debug_statements
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay before retry
                await processQueue()
            }
            
        } catch {
            // Re-queue all operations on error
            pendingServerOperations.insert(contentsOf: operationsToProcess, at: 0)
            
            // Calculate the maximum retry count from all operations
            let maxRetryCount = operationsToProcess.compactMap { operation in
                operationResults[operation.id]?.retryCount
            }.max() ?? 0
            let newRetryCount = maxRetryCount + 1
            
            // Update operation results with error
            for operation in operationsToProcess {
                let existingResult = operationResults[operation.id]
                let retryCount = (existingResult?.retryCount ?? 0) + 1
                let result = OperationResult(
                    operationId: operation.id,
                    success: false,
                    error: error,
                    retryCount: retryCount
                )
                operationResults[operation.id] = result
            }
            
            // Retry after delay (with exponential backoff)
            let delay = min(UInt64(pow(2.0, Double(min(newRetryCount, 5)))) * 1_000_000_000, 30_000_000_000) // Max 30 seconds
            // swiftlint:disable:next common_debug_statements
            try? await Task.sleep(nanoseconds: delay)
            await processQueue()
        }
    }
    
    public func retryFailedOperations() async {
        let failedOperations = pendingServerOperations.filter { operation in
            let result = operationResults[operation.id]
            return result?.success == false
        }
        
        if !failedOperations.isEmpty {
            await processQueue()
        }
    }
    
    public func getOperationResult(for operationId: UUID) -> OperationResult? {
        operationResults[operationId]
    }
    
    public func clearOperationResults() {
        operationResults.removeAll()
    }
    
    public var pendingOperationCount: Int {
        pendingServerOperations.count
    }
    
    public var failedOperationCount: Int {
        pendingServerOperations.filter { operation in
            let result = operationResults[operation.id]
            return result?.success == false
        }.count
    }
} 
