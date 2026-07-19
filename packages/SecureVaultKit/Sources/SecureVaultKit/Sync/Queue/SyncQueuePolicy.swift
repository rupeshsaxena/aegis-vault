public struct SyncQueuePolicy: Codable, Equatable, Sendable {
    public var maxBatchSize: Int

    public init(maxBatchSize: Int = 50) {
        self.maxBatchSize = max(1, maxBatchSize)
    }
}

