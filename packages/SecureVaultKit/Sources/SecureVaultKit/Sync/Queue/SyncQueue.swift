public protocol SyncQueue: Sendable {
    func enqueue(_ operation: SyncOperation) async throws
    func nextBatch(for vaultId: VaultID) async throws -> SyncBatch
    func markCompleted(_ operationIds: [SyncOperationID]) async throws
    func markFailed(_ operationId: SyncOperationID, failure: SyncFailure) async throws
}

