import Foundation

internal protocol BlobRepository: Sendable {
    func create(
        from data: Data,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult

    func create(
        from fileURL: URL,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult

    func load(id: BlobID) async throws -> BlobRecord
    func delete(id: BlobID) async throws
}

internal struct DefaultBlobRepository: BlobRepository {
    private let blobStore: any BlobStore

    init(blobStore: any BlobStore) {
        self.blobStore = blobStore
    }

    func create(
        from data: Data,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        try await blobStore.writeBlob(data, contentType: contentType, role: role)
    }

    func create(
        from fileURL: URL,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        try await blobStore.writeBlob(from: fileURL, contentType: contentType, role: role)
    }

    func load(id: BlobID) async throws -> BlobRecord {
        guard let record = try await blobStore.listBlobs().first(where: { $0.id == id }) else {
            throw VaultError.unsupportedOperation("Blob record not found.")
        }
        return record
    }

    func delete(id: BlobID) async throws {
        try await blobStore.deleteBlob(id: id)
    }
}
