import Foundation

internal protocol BlobStore: Sendable {
    func writeBlob(_ data: Data, contentType: String) async throws -> BlobWriteResult
    func writeBlob(from fileURL: URL, contentType: String) async throws -> BlobWriteResult
    func readBlob(id: BlobID) async throws -> Data
    func deleteBlob(id: BlobID) async throws
    func blobExists(id: BlobID) async throws -> Bool
    func listBlobs() async throws -> [BlobRecord]
}

extension BlobStore {
    func writeBlob(from fileURL: URL, contentType: String) async throws -> BlobWriteResult {
        let data = try Data(contentsOf: fileURL)
        return try await writeBlob(data, contentType: contentType)
    }
}
