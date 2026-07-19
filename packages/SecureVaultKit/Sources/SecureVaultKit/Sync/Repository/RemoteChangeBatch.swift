public struct RemoteChangeBatch: Codable, Equatable, Sendable {
    public var operations: [SyncOperation]
    public var cursor: SyncCursor?

    public init(operations: [SyncOperation] = [], cursor: SyncCursor? = nil) {
        self.operations = operations
        self.cursor = cursor
    }
}

