import Foundation

internal enum BlobRole: String, Codable, Sendable {
    case original
    case thumbnail
    case preview
    case supporting
}

internal struct BlobRecord: Equatable, Sendable {
    var id: BlobID
    var role: BlobRole
    var contentType: String
    var byteCount: Int
    var storagePath: String?
    var createdAt: Date

    init(
        id: BlobID,
        role: BlobRole = .original,
        contentType: String,
        byteCount: Int,
        storagePath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.contentType = contentType
        self.byteCount = byteCount
        self.storagePath = storagePath
        self.createdAt = createdAt
    }
}

internal struct BlobWriteResult: Equatable, Sendable {
    var id: BlobID
    var byteCount: Int
    var contentType: String
    var record: BlobRecord

    init(
        id: BlobID,
        byteCount: Int,
        contentType: String,
        record: BlobRecord? = nil
    ) {
        self.id = id
        self.byteCount = byteCount
        self.contentType = contentType
        self.record = record ?? BlobRecord(
            id: id,
            contentType: contentType,
            byteCount: byteCount
        )
    }
}

internal struct BlobManifest: Equatable, Sendable {
    var records: [BlobRecord]

    init(records: [BlobRecord] = []) {
        self.records = records
    }
}
