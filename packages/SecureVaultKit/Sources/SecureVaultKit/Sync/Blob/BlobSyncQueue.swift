public actor BlobSyncQueue {
    private var operations: [BlobSyncOperation] = []

    public init() {}

    public func enqueue(_ operation: BlobSyncOperation) {
        guard !operations.contains(where: { $0.operationId == operation.operationId }) else {
            return
        }
        operations.append(operation)
    }

    public func pending() -> [BlobSyncOperation] {
        operations
    }
}

