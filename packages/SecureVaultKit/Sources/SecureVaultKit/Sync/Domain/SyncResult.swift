public struct SyncResult: Codable, Equatable, Sendable {
    public var uploadedCount: Int
    public var downloadedCount: Int
    public var conflictCount: Int
    public var nextCursor: SyncCursor?

    public init(
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        nextCursor: SyncCursor? = nil
    ) {
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.nextCursor = nextCursor
    }
}

