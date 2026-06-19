import Foundation

internal protocol BlobEncryptionEngine: Sendable {
    func encryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> EncryptedBlobResult

    func decryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> DecryptedBlobResult
}

internal struct EncryptedBlobResult: Equatable, Sendable {
    var blobId: BlobID
    var envelope: EncryptedEnvelope
    var originalSizeBytes: Int64
    var encryptedSizeBytes: Int64
    var checksum: String
    var createdAt: Date

    init(
        blobId: BlobID,
        envelope: EncryptedEnvelope,
        originalSizeBytes: Int64,
        encryptedSizeBytes: Int64,
        checksum: String,
        createdAt: Date = Date()
    ) {
        self.blobId = blobId
        self.envelope = envelope
        self.originalSizeBytes = originalSizeBytes
        self.encryptedSizeBytes = encryptedSizeBytes
        self.checksum = checksum
        self.createdAt = createdAt
    }
}

internal struct DecryptedBlobResult: Equatable, Sendable {
    var outputURL: URL
    var sizeBytes: Int64
    var checksum: String
}

internal struct BlobEncryptionPolicy: Equatable, Sendable {
    static let `default` = BlobEncryptionPolicy()

    var chunkSize: Int
    var algorithm: CryptoAlgorithm
    var maxFileSizeBytes: Int64
    var verifyChecksum: Bool

    init(
        chunkSize: Int = 64 * 1_024,
        algorithm: CryptoAlgorithm = .xChaCha20Poly1305,
        maxFileSizeBytes: Int64 = 2 * 1_024 * 1_024 * 1_024,
        verifyChecksum: Bool = true
    ) {
        self.chunkSize = chunkSize
        self.algorithm = algorithm
        self.maxFileSizeBytes = maxFileSizeBytes
        self.verifyChecksum = verifyChecksum
    }
}

internal enum BlobEncryptionError: Error, Equatable, Sendable {
    case invalidPolicy
    case fileTooLarge(maxFileSizeBytes: Int64)
    case keyMismatch
    case injectedFailure
}
