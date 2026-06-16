import Foundation

public actor InMemoryBlobStore: BlobStore {
    private var blobs: [BlobID: Data] = [:]

    public init(blobs: [BlobID: Data] = [:]) {
        self.blobs = blobs
    }

    public func putBlob(id: BlobID, data: Data) async throws {
        blobs[id] = data
    }

    public func getBlob(id: BlobID) async throws -> Data {
        guard let data = blobs[id] else {
            throw SecureVaultError.blobNotFound(id)
        }
        return data
    }

    public func deleteBlob(id: BlobID) async throws {
        guard blobs.removeValue(forKey: id) != nil else {
            throw SecureVaultError.blobNotFound(id)
        }
    }
}
