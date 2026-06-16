internal struct VaultKitConfiguration: Sendable {
    let cryptoEngine: any CryptoEngine
    let storageEngine: any StorageEngine
    let blobStore: any BlobStore
    let eventEngine: any EventEngine
    let deviceTrustEngine: any DeviceTrustEngine
    let searchEngine: any SearchEngine

    init(
        cryptoEngine: any CryptoEngine,
        storageEngine: any StorageEngine,
        blobStore: any BlobStore,
        eventEngine: any EventEngine,
        deviceTrustEngine: any DeviceTrustEngine,
        searchEngine: any SearchEngine
    ) {
        self.cryptoEngine = cryptoEngine
        self.storageEngine = storageEngine
        self.blobStore = blobStore
        self.eventEngine = eventEngine
        self.deviceTrustEngine = deviceTrustEngine
        self.searchEngine = searchEngine
    }
}
