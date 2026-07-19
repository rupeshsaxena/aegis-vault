public enum BlobSyncState: String, Codable, Sendable {
    case pendingUpload = "pending_upload"
    case uploaded
    case failed
}

