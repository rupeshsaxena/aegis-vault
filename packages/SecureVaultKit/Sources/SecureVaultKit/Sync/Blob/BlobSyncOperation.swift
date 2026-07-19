public struct BlobSyncOperation: Codable, Equatable, Sendable {
    public var blobId: BlobID
    public var role: String
    public var operationId: SyncOperationID

    public init(blobId: BlobID, role: String, operationId: SyncOperationID = SyncOperationID()) {
        self.blobId = blobId
        self.role = role
        self.operationId = operationId
    }
}

