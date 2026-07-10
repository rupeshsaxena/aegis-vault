internal protocol ThumbnailCache: Sendable {
    func value(for objectId: VaultObjectID) async -> VaultThumbnail?
    func insert(_ thumbnail: VaultThumbnail) async
    func removeValue(for objectId: VaultObjectID) async
    func clear() async
    func count() async -> Int
}

internal actor InMemoryThumbnailCache: ThumbnailCache {
    private var values: [VaultObjectID: VaultThumbnail] = [:]
    private var accessOrder: [VaultObjectID] = []
    private var estimatedBytes = 0
    private let maximumItemCount: Int
    private let estimatedByteLimit: Int?

    init(maximumItemCount: Int = 128, estimatedByteLimit: Int? = 16 * 1_024 * 1_024) {
        self.maximumItemCount = max(0, maximumItemCount)
        self.estimatedByteLimit = estimatedByteLimit
    }

    func value(for objectId: VaultObjectID) -> VaultThumbnail? {
        guard let value = values[objectId] else { return nil }
        markRecentlyUsed(objectId)
        return value
    }

    func insert(_ thumbnail: VaultThumbnail) {
        if let existing = values[thumbnail.objectId] {
            estimatedBytes -= existing.data.count
        }
        values[thumbnail.objectId] = thumbnail
        estimatedBytes += thumbnail.data.count
        markRecentlyUsed(thumbnail.objectId)
        evictIfNeeded()
    }

    func removeValue(for objectId: VaultObjectID) {
        if let existing = values.removeValue(forKey: objectId) {
            estimatedBytes -= existing.data.count
        }
        accessOrder.removeAll { $0 == objectId }
    }

    func clear() {
        values.removeAll(keepingCapacity: false)
        accessOrder.removeAll(keepingCapacity: false)
        estimatedBytes = 0
    }

    func count() -> Int {
        values.count
    }

    private func markRecentlyUsed(_ objectId: VaultObjectID) {
        accessOrder.removeAll { $0 == objectId }
        accessOrder.append(objectId)
    }

    private func evictIfNeeded() {
        while shouldEvict, let oldest = accessOrder.first {
            removeOldest(oldest)
        }
    }

    private var shouldEvict: Bool {
        if values.count > maximumItemCount {
            return true
        }
        if let estimatedByteLimit, estimatedBytes > estimatedByteLimit {
            return true
        }
        return false
    }

    private func removeOldest(_ objectId: VaultObjectID) {
        accessOrder.removeFirst()
        if let existing = values.removeValue(forKey: objectId) {
            estimatedBytes -= existing.data.count
        }
    }
}
