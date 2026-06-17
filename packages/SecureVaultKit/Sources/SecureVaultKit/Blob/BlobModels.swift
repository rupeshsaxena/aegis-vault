import Foundation

internal enum BlobRole: String, Codable, Sendable {
    case original
    case thumbnail
    case preview
    case supporting
}

internal struct BlobEncryptionMetadata: Equatable, Sendable {
    var algorithm: String
    var keyReference: String
    var isPlaintextPersisted: Bool

    init(
        algorithm: String,
        keyReference: String,
        isPlaintextPersisted: Bool
    ) {
        self.algorithm = algorithm
        self.keyReference = keyReference
        self.isPlaintextPersisted = isPlaintextPersisted
    }

    static func fakeProtected(keyReference: String = "fake-blob-key") -> BlobEncryptionMetadata {
        BlobEncryptionMetadata(
            algorithm: "in-memory.fake-protected-blob",
            keyReference: keyReference,
            isPlaintextPersisted: false
        )
    }
}

internal struct BlobRecord: Equatable, Sendable {
    var id: BlobID
    var role: BlobRole
    var contentType: String
    var byteCount: Int
    var storagePath: String?
    var encryptionMetadata: BlobEncryptionMetadata
    var createdAt: Date

    init(
        id: BlobID,
        role: BlobRole = .original,
        contentType: String,
        byteCount: Int,
        storagePath: String? = nil,
        encryptionMetadata: BlobEncryptionMetadata = .fakeProtected(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.contentType = contentType
        self.byteCount = byteCount
        self.storagePath = storagePath
        self.encryptionMetadata = encryptionMetadata
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

internal enum FakeBlobProtection {
    private static let prefix = Data("SecureVaultKit.fake-protected-blob\n".utf8)

    static func protect(_ data: Data) -> Data {
        prefix + Data(data.base64EncodedString().utf8)
    }

    static func unprotect(_ data: Data) -> Data {
        guard data.starts(with: prefix) else {
            return data
        }
        let encoded = data.dropFirst(prefix.count)
        guard let encodedString = String(data: encoded, encoding: .utf8),
              let decoded = Data(base64Encoded: encodedString) else {
            return data
        }
        return decoded
    }
}
