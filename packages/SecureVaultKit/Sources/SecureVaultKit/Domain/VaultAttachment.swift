public enum AttachmentRole: String, CaseIterable, Codable, Sendable {
    case primary
    case thumbnail
    case preview
    case supporting
}

public struct VaultAttachment: Equatable, Codable, Sendable {
    public var id: BlobID
    public var role: AttachmentRole
    public var fileName: String
    public var contentType: String
    public var byteCount: Int

    public init(
        id: BlobID,
        role: AttachmentRole,
        fileName: String,
        contentType: String,
        byteCount: Int
    ) {
        self.id = id
        self.role = role
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = byteCount
    }
}
