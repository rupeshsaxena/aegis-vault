public protocol SyncEngine: Sendable {
    func recordLocalMutation(_ operation: SyncOperation) async throws
    func pendingOperations(for vaultId: VaultID, limit: Int) async throws -> [SyncOperation]
    func synchronize(context: SyncExecutionContext) async throws -> SyncResult
}

