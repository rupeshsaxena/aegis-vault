import Foundation

internal actor PersistentLocalBlobStore: BlobStore {
    private let fileStore: FileSystemBlobStore
    private let storageEngine: SQLiteStorageEngine

    init(rootDirectory: URL, storageEngine: SQLiteStorageEngine) throws {
        self.fileStore = try FileSystemBlobStore(rootDirectory: rootDirectory)
        self.storageEngine = storageEngine
    }

    func writeBlob(_ data: Data, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        let result = try await fileStore.writeBlob(data, contentType: contentType, role: role)
        try await storageEngine.upsertBlobRecord(result.record)
        return result
    }

    func writeBlob(from fileURL: URL, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        let result = try await fileStore.writeBlob(from: fileURL, contentType: contentType, role: role)
        try await storageEngine.upsertBlobRecord(result.record)
        return result
    }

    func writeEncryptedBlob(
        from fileURL: URL,
        result: EncryptedBlobResult,
        wrappedKey: WrappedKey,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        let writeResult = try await fileStore.writeEncryptedBlob(
            from: fileURL,
            result: result,
            wrappedKey: wrappedKey,
            contentType: contentType,
            role: role
        )
        try await storageEngine.upsertBlobRecord(writeResult.record)
        return writeResult
    }

    func readBlob(id: BlobID) async throws -> Data {
        try await fileStore.readBlob(id: id)
    }

    func deleteBlob(id: BlobID) async throws {
        try await fileStore.deleteBlob(id: id)
    }

    func blobExists(id: BlobID) async throws -> Bool {
        try await fileStore.blobExists(id: id)
    }

    func listBlobs() async throws -> [BlobRecord] {
        try await storageEngine.listPersistedBlobRecords()
    }
}
