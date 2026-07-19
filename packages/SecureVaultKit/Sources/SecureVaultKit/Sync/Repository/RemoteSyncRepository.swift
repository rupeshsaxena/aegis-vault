public protocol RemoteSyncRepository: Sendable {
    func upload(_ batch: SyncBatch, context: SyncExecutionContext) async throws -> SyncResult
    func fetchChanges(after cursor: SyncCursor?, context: SyncExecutionContext) async throws -> RemoteChangeBatch
}

public struct NoopRemoteSyncRepository: RemoteSyncRepository {
    public init() {}

    public func upload(_ batch: SyncBatch, context: SyncExecutionContext) async throws -> SyncResult {
        SyncResult(uploadedCount: batch.operations.count)
    }

    public func fetchChanges(after cursor: SyncCursor?, context: SyncExecutionContext) async throws -> RemoteChangeBatch {
        RemoteChangeBatch(cursor: cursor)
    }
}

