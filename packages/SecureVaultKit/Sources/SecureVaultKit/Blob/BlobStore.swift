import Foundation

internal protocol BlobStore: Sendable {
    func writeBlob(_ data: Data, contentType: String) async throws -> BlobWriteResult
    func readBlob(id: BlobID) async throws -> Data
    func deleteBlob(id: BlobID) async throws
}
