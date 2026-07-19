public struct PersistentSyncQueue: SyncQueue {
    private let journal: any SyncJournal
    private let policy: SyncQueuePolicy

    public init(journal: any SyncJournal, policy: SyncQueuePolicy = SyncQueuePolicy()) {
        self.journal = journal
        self.policy = policy
    }

    public func enqueue(_ operation: SyncOperation) async throws {
        try await journal.append(SyncJournalEntry(operation: operation))
    }

    public func nextBatch(for vaultId: VaultID) async throws -> SyncBatch {
        let operations = try await journal.pendingOperations(for: vaultId, limit: policy.maxBatchSize)
        try await journal.markInFlight(operations.map(\.id))
        return SyncBatch(operations: operations)
    }

    public func markCompleted(_ operationIds: [SyncOperationID]) async throws {
        try await journal.markCompleted(operationIds)
    }

    public func markFailed(_ operationId: SyncOperationID, failure: SyncFailure) async throws {
        try await journal.markFailed(operationId, failure: failure)
    }
}

