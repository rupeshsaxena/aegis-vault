public protocol SessionCleanupHandler: Sendable {
    func clearSearchIndex() async
    func clearPreviewCache() async
    func clearThumbnailCache() async
    func clearDecryptedObjectCache() async
}

public actor FakeSessionCleanupHandler: SessionCleanupHandler {
    public private(set) var searchIndexClearCount = 0
    public private(set) var previewCacheClearCount = 0
    public private(set) var thumbnailCacheClearCount = 0
    public private(set) var decryptedObjectCacheClearCount = 0

    public init() {}

    public func clearSearchIndex() {
        searchIndexClearCount += 1
    }

    public func clearPreviewCache() {
        previewCacheClearCount += 1
    }

    public func clearThumbnailCache() {
        thumbnailCacheClearCount += 1
    }

    public func clearDecryptedObjectCache() {
        decryptedObjectCacheClearCount += 1
    }
}

internal struct VaultEngineSessionCleanupHandler: SessionCleanupHandler {
    private let searchEngine: any SearchEngine
    private let thumbnailCache: any ThumbnailCache

    init(searchEngine: any SearchEngine, thumbnailCache: any ThumbnailCache) {
        self.searchEngine = searchEngine
        self.thumbnailCache = thumbnailCache
    }

    func clearSearchIndex() async {
        await searchEngine.clear()
    }

    func clearPreviewCache() async {}

    func clearThumbnailCache() async {
        await thumbnailCache.clear()
    }

    func clearDecryptedObjectCache() async {}
}
