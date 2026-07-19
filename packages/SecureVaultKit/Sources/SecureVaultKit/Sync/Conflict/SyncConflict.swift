public struct SyncConflict: Codable, Equatable, Sendable {
    public var local: SyncOperation
    public var remote: SyncOperation
    public var type: ConflictType

    public init(local: SyncOperation, remote: SyncOperation, type: ConflictType) {
        self.local = local
        self.remote = remote
        self.type = type
    }
}

