internal struct PersistentSyncJournal: SyncJournal {
    private let storageEngine: SQLiteStorageEngine

    init(storageEngine: SQLiteStorageEngine) {
        self.storageEngine = storageEngine
    }

    func append(_ entry: SyncJournalEntry) async throws {
        try await storageEngine.appendSyncJournalEntry(entry)
    }

    func update(_ operation: SyncOperation) async throws {
        try await storageEngine.updateSyncOperation(operation)
    }

    func entries(for vaultId: VaultID) async throws -> [SyncJournalEntry] {
        try await storageEngine.listSyncJournalEntries(for: vaultId)
    }

    func pendingOperations(for vaultId: VaultID, limit: Int) async throws -> [SyncOperation] {
        try await storageEngine.listPendingSyncOperations(for: vaultId, limit: limit)
    }

    func markInFlight(_ operationIds: [SyncOperationID]) async throws {
        try await storageEngine.updateSyncOperationState(operationIds, state: .inFlight)
    }

    func markCompleted(_ operationIds: [SyncOperationID]) async throws {
        try await storageEngine.updateSyncOperationState(operationIds, state: .completed)
    }

    func markFailed(_ operationId: SyncOperationID, failure: SyncFailure) async throws {
        try await storageEngine.markSyncOperationFailed(operationId, failure: failure)
    }
}

