public protocol LocalSyncRepository: Sendable {
    func applyRemoteOperations(_ operations: [SyncOperation], context: SyncExecutionContext) async throws -> Int
}

public struct NoopLocalSyncRepository: LocalSyncRepository {
    public init() {}

    public func applyRemoteOperations(_ operations: [SyncOperation], context: SyncExecutionContext) async throws -> Int {
        operations.count
    }
}

