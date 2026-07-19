import Foundation

public protocol SyncJournal: Sendable {
    func append(_ entry: SyncJournalEntry) async throws
    func update(_ operation: SyncOperation) async throws
    func entries(for vaultId: VaultID) async throws -> [SyncJournalEntry]
    func pendingOperations(for vaultId: VaultID, limit: Int) async throws -> [SyncOperation]
    func markInFlight(_ operationIds: [SyncOperationID]) async throws
    func markCompleted(_ operationIds: [SyncOperationID]) async throws
    func markFailed(_ operationId: SyncOperationID, failure: SyncFailure) async throws
}

internal actor InMemorySyncJournal: SyncJournal {
    private var entriesById: [SyncOperationID: SyncJournalEntry] = [:]

    func append(_ entry: SyncJournalEntry) async throws {
        if entriesById[entry.operation.id] == nil {
            entriesById[entry.operation.id] = entry
        }
    }

    func update(_ operation: SyncOperation) async throws {
        guard var entry = entriesById[operation.id] else {
            throw SyncFailure(code: "sync_operation_not_found", safeMessage: "Sync operation was not found.")
        }
        entry.operation = operation
        entriesById[operation.id] = entry
    }

    func entries(for vaultId: VaultID) async throws -> [SyncJournalEntry] {
        entriesById.values
            .filter { $0.operation.vaultId == vaultId }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func pendingOperations(for vaultId: VaultID, limit: Int) async throws -> [SyncOperation] {
        Array(
            entriesById.values
                .map(\.operation)
                .filter { $0.vaultId == vaultId && $0.state == .pending }
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(limit)
        )
    }

    func markInFlight(_ operationIds: [SyncOperationID]) async throws {
        try update(operationIds: operationIds) { operation in
            operation.state = .inFlight
            operation.updatedAt = Date()
        }
    }

    func markCompleted(_ operationIds: [SyncOperationID]) async throws {
        try update(operationIds: operationIds) { operation in
            operation.state = .completed
            operation.updatedAt = Date()
        }
    }

    func markFailed(_ operationId: SyncOperationID, failure: SyncFailure) async throws {
        try update(operationIds: [operationId]) { operation in
            operation.state = .failed
            operation.attemptCount += 1
            operation.lastFailure = failure
            operation.updatedAt = Date()
        }
    }

    private func update(
        operationIds: [SyncOperationID],
        mutate: (inout SyncOperation) -> Void
    ) throws {
        for operationId in operationIds {
            guard var entry = entriesById[operationId] else {
                throw SyncFailure(code: "sync_operation_not_found", safeMessage: "Sync operation was not found.")
            }
            mutate(&entry.operation)
            entriesById[operationId] = entry
        }
    }
}
