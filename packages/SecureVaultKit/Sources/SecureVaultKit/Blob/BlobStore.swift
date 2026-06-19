import Foundation

internal protocol BlobStore: Sendable {
    func writeBlob(_ data: Data, contentType: String, role: BlobRole) async throws -> BlobWriteResult
    func writeBlob(from fileURL: URL, contentType: String, role: BlobRole) async throws -> BlobWriteResult
    func writeEncryptedBlob(
        from fileURL: URL,
        result: EncryptedBlobResult,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult
    func readBlob(id: BlobID) async throws -> Data
    func deleteBlob(id: BlobID) async throws
    func blobExists(id: BlobID) async throws -> Bool
    func listBlobs() async throws -> [BlobRecord]
}

extension BlobStore {
    func writeBlob(_ data: Data, contentType: String) async throws -> BlobWriteResult {
        try await writeBlob(data, contentType: contentType, role: .original)
    }

    func writeBlob(from fileURL: URL, contentType: String) async throws -> BlobWriteResult {
        try await writeBlob(from: fileURL, contentType: contentType, role: .original)
    }
}
