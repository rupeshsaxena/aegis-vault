public struct DefaultSyncEngine: SyncEngine {
    private let journal: any SyncJournal
    private let queue: any SyncQueue
    private let localRepository: any LocalSyncRepository
    private let remoteRepository: any RemoteSyncRepository
    private let eventSink: (any SyncEventSink)?

    public init(
        journal: any SyncJournal,
        queue: any SyncQueue,
        localRepository: any LocalSyncRepository = NoopLocalSyncRepository(),
        remoteRepository: any RemoteSyncRepository = NoopRemoteSyncRepository(),
        eventSink: (any SyncEventSink)? = nil
    ) {
        self.journal = journal
        self.queue = queue
        self.localRepository = localRepository
        self.remoteRepository = remoteRepository
        self.eventSink = eventSink
    }

    public func recordLocalMutation(_ operation: SyncOperation) async throws {
        try await queue.enqueue(operation)
        try await eventSink?.emit(.operationRecorded(operation.id))
    }

    public func pendingOperations(for vaultId: VaultID, limit: Int) async throws -> [SyncOperation] {
        try await journal.pendingOperations(for: vaultId, limit: limit)
    }

    public func synchronize(context: SyncExecutionContext) async throws -> SyncResult {
        try Task.checkCancellation()
        let batch = try await queue.nextBatch(for: context.vaultId)
        do {
            let uploadResult = try await remoteRepository.upload(batch, context: context)
            try await queue.markCompleted(batch.operations.map(\.id))
            try Task.checkCancellation()
            let remoteChanges = try await remoteRepository.fetchChanges(after: context.cursor, context: context)
            let appliedCount = try await localRepository.applyRemoteOperations(
                remoteChanges.operations,
                context: context
            )
            let result = SyncResult(
                uploadedCount: uploadResult.uploadedCount,
                downloadedCount: appliedCount,
                conflictCount: uploadResult.conflictCount,
                nextCursor: remoteChanges.cursor ?? uploadResult.nextCursor
            )
            try await eventSink?.emit(.syncCompleted(result))
            return result
        } catch is CancellationError {
            for operation in batch.operations {
                try? await queue.markFailed(operation.id, failure: .cancelled)
            }
            throw CancellationError()
        } catch {
            for operation in batch.operations {
                try? await queue.markFailed(
                    operation.id,
                    failure: SyncFailure(code: "sync_failed", safeMessage: "Synchronization failed.")
                )
            }
            throw error
        }
    }
}

