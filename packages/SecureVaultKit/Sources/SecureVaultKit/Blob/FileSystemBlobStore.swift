import Foundation

internal actor FileSystemBlobStore: BlobStore {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private var records: [BlobID: BlobRecord] = [:]

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: rootDirectory.appendingPathComponent("blobs", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func writeBlob(_ data: Data, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SecureVaultKitBlob-\(UUID().uuidString)")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        return try await writeBlob(from: temporaryURL, contentType: contentType, role: role)
    }

    func writeBlob(from fileURL: URL, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        let id = BlobID()
        let destinationURL = storageURL(for: id)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        let plaintextData = try Data(contentsOf: fileURL)
        try FakeBlobProtection.protect(plaintextData).write(to: destinationURL, options: .atomic)
        let byteCount = plaintextData.count
        let relativePath = "blobs/\(prefix(for: id))/\(id.rawValue).blob"
        let record = BlobRecord(
            id: id,
            role: role,
            contentType: contentType,
            byteCount: byteCount,
            storagePath: relativePath,
            encryptionMetadata: .fakeProtected(keyReference: "fake-filesystem-blob-key")
        )
        records[id] = record
        return BlobWriteResult(
            id: id,
            byteCount: byteCount,
            contentType: contentType,
            record: record
        )
    }

    func writeEncryptedBlob(
        from fileURL: URL,
        result: EncryptedBlobResult,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        let destinationURL = storageURL(for: result.blobId)
        _ = try StreamingFileCopy.copy(
            from: fileURL,
            to: destinationURL,
            chunkSize: BlobEncryptionPolicy.default.chunkSize,
            fileManager: fileManager
        )
        let relativePath = "blobs/\(prefix(for: result.blobId))/\(result.blobId.rawValue).blob"
        let record = BlobRecord(
            id: result.blobId,
            role: role,
            contentType: contentType,
            byteCount: Int(result.originalSizeBytes),
            storagePath: relativePath,
            encryptionMetadata: .encryptedBlob(result),
            createdAt: result.createdAt
        )
        records[result.blobId] = record
        return BlobWriteResult(
            id: result.blobId,
            byteCount: Int(result.originalSizeBytes),
            contentType: contentType,
            record: record
        )
    }

    func readBlob(id: BlobID) async throws -> Data {
        guard records[id] != nil, fileManager.fileExists(atPath: storageURL(for: id).path) else {
            throw VaultError.unsupportedOperation("Blob not found.")
        }
        return try FakeBlobProtection.unprotect(Data(contentsOf: storageURL(for: id)))
    }

    func deleteBlob(id: BlobID) async throws {
        let url = storageURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        records[id] = nil
    }

    func blobExists(id: BlobID) async throws -> Bool {
        records[id] != nil && fileManager.fileExists(atPath: storageURL(for: id).path)
    }

    func listBlobs() async throws -> [BlobRecord] {
        records.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func storageURL(for id: BlobID) -> URL {
        rootDirectory
            .appendingPathComponent("blobs", isDirectory: true)
            .appendingPathComponent(prefix(for: id), isDirectory: true)
            .appendingPathComponent("\(id.rawValue).blob")
    }

    private func prefix(for id: BlobID) -> String {
        String(id.rawValue.prefix(2))
    }

}
