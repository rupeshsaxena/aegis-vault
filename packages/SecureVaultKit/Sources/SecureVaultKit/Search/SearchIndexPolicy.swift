internal enum SearchIndexStorageMode: Equatable, Sendable {
    case inMemoryOnly
    case encryptedPersistentFuture
}

internal struct SearchIndexPolicy: Equatable, Sendable {
    static let `default` = SearchIndexPolicy()

    var storageMode: SearchIndexStorageMode
    var rebuildOnUnlock: Bool
    var clearOnLock: Bool
    var includeDeleted: Bool

    init(
        storageMode: SearchIndexStorageMode = .inMemoryOnly,
        rebuildOnUnlock: Bool = true,
        clearOnLock: Bool = true,
        includeDeleted: Bool = false
    ) {
        self.storageMode = storageMode
        self.rebuildOnUnlock = rebuildOnUnlock
        self.clearOnLock = clearOnLock
        self.includeDeleted = includeDeleted
    }
}
