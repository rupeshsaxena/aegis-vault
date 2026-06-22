internal protocol ThumbnailCache: Sendable {
    func value(for objectId: VaultObjectID) async -> VaultThumbnail?
    func insert(_ thumbnail: VaultThumbnail) async
    func removeValue(for objectId: VaultObjectID) async
    func clear() async
    func count() async -> Int
}

internal actor InMemoryThumbnailCache: ThumbnailCache {
    private var values: [VaultObjectID: VaultThumbnail] = [:]

    func value(for objectId: VaultObjectID) -> VaultThumbnail? {
        values[objectId]
    }

    func insert(_ thumbnail: VaultThumbnail) {
        values[thumbnail.objectId] = thumbnail
    }

    func removeValue(for objectId: VaultObjectID) {
        values[objectId] = nil
    }

    func clear() {
        values.removeAll(keepingCapacity: false)
    }

    func count() -> Int {
        values.count
    }
}
