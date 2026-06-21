public enum AttachmentRole: String, CaseIterable, Codable, Sendable {
    case primary
    case thumbnail
    case preview
    case supporting
}

public struct VaultAttachment: Equatable, Codable, Sendable {
    public var attachmentId: AttachmentID
    public var blobId: BlobID
    public var role: AttachmentRole
    public var fileName: String
    public var contentType: String
    public var originalSizeBytes: Int
    public var thumbnailBlobId: BlobID?
    public var previewBlobId: BlobID?

    public var id: BlobID {
        get { blobId }
        set { blobId = newValue }
    }

    public var byteCount: Int {
        get { originalSizeBytes }
        set { originalSizeBytes = newValue }
    }

    public var filename: String {
        get { fileName }
        set { fileName = newValue }
    }

    public init(
        id: BlobID,
        role: AttachmentRole,
        fileName: String,
        contentType: String,
        byteCount: Int,
        attachmentId: AttachmentID = AttachmentID(),
        thumbnailBlobId: BlobID? = nil,
        previewBlobId: BlobID? = nil
    ) {
        self.attachmentId = attachmentId
        self.blobId = id
        self.role = role
        self.fileName = fileName
        self.contentType = contentType
        self.originalSizeBytes = byteCount
        self.thumbnailBlobId = thumbnailBlobId
        self.previewBlobId = previewBlobId
    }


    public init(
        attachmentId: AttachmentID = AttachmentID(),
        blobId: BlobID,
        filename: String,
        contentType: String,
        originalSizeBytes: Int,
        role: AttachmentRole = .primary,
        thumbnailBlobId: BlobID? = nil,
        previewBlobId: BlobID? = nil
    ) {
        self.attachmentId = attachmentId
        self.blobId = blobId
        self.role = role
        self.fileName = filename
        self.contentType = contentType
        self.originalSizeBytes = originalSizeBytes
        self.thumbnailBlobId = thumbnailBlobId
        self.previewBlobId = previewBlobId
    }

    private enum CodingKeys: String, CodingKey {
        case attachmentId
        case blobId
        case role
        case fileName
        case contentType
        case originalSizeBytes
        case thumbnailBlobId
        case previewBlobId
        case id
        case byteCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedBlobId = try container.decodeIfPresent(BlobID.self, forKey: .blobId)
            ?? container.decode(BlobID.self, forKey: .id)
        attachmentId = try container.decodeIfPresent(AttachmentID.self, forKey: .attachmentId)
            ?? AttachmentID(decodedBlobId.rawValue)
        blobId = decodedBlobId
        role = try container.decode(AttachmentRole.self, forKey: .role)
        fileName = try container.decode(String.self, forKey: .fileName)
        contentType = try container.decode(String.self, forKey: .contentType)
        originalSizeBytes = try container.decodeIfPresent(Int.self, forKey: .originalSizeBytes)
            ?? container.decode(Int.self, forKey: .byteCount)
        thumbnailBlobId = try container.decodeIfPresent(BlobID.self, forKey: .thumbnailBlobId)
        previewBlobId = try container.decodeIfPresent(BlobID.self, forKey: .previewBlobId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attachmentId, forKey: .attachmentId)
        try container.encode(blobId, forKey: .blobId)
        try container.encode(role, forKey: .role)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(originalSizeBytes, forKey: .originalSizeBytes)
        try container.encodeIfPresent(thumbnailBlobId, forKey: .thumbnailBlobId)
        try container.encodeIfPresent(previewBlobId, forKey: .previewBlobId)
    }
}
