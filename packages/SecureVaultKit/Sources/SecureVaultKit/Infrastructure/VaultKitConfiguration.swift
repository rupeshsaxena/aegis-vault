internal struct VaultKitConfiguration: Sendable {
    let cryptoEngine: any CryptoEngine
    let storageEngine: any StorageEngine
    let blobStore: any BlobStore
    let blobEncryptionEngine: any BlobEncryptionEngine
    let eventEngine: any EventEngine
    let deviceTrustEngine: any DeviceTrustEngine
    let searchEngine: any SearchEngine

    init(
        cryptoEngine: any CryptoEngine,
        storageEngine: any StorageEngine,
        blobStore: any BlobStore,
        blobEncryptionEngine: any BlobEncryptionEngine = RealBlobEncryptionEngine(),
        eventEngine: any EventEngine,
        deviceTrustEngine: any DeviceTrustEngine,
        searchEngine: any SearchEngine
    ) {
        self.cryptoEngine = cryptoEngine
        self.storageEngine = storageEngine
        self.blobStore = blobStore
        self.blobEncryptionEngine = blobEncryptionEngine
        self.eventEngine = eventEngine
        self.deviceTrustEngine = deviceTrustEngine
        self.searchEngine = searchEngine
    }
}
