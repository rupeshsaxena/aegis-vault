import Foundation

internal struct RealBlobEncryptionEngine: BlobEncryptionEngine {
    init(policy: BlobEncryptionPolicy = .default) {}

    func encryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> EncryptedBlobResult {
        throw CryptoError.notImplemented
    }

    func decryptBlob(
        inputURL: URL,
        outputURL: URL,
        using key: SymmetricKeyMaterial
    ) async throws -> DecryptedBlobResult {
        throw CryptoError.notImplemented
    }
}
