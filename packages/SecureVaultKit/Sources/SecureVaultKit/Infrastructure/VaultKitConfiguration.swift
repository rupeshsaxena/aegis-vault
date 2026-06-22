internal struct VaultKitConfiguration: Sendable {
    let cryptoEngine: any CryptoEngine
    let storageEngine: any StorageEngine
    let blobStore: any BlobStore
    let blobEncryptionEngine: any BlobEncryptionEngine
    let eventEngine: any EventEngine
    let deviceTrustEngine: any DeviceTrustEngine
    let searchEngine: any SearchEngine
    let biometricAuthProvider: (any BiometricAuthProvider)?

    init(
        cryptoEngine: any CryptoEngine,
        storageEngine: any StorageEngine,
        blobStore: any BlobStore,
        blobEncryptionEngine: any BlobEncryptionEngine = RealBlobEncryptionEngine(),
        eventEngine: any EventEngine,
        deviceTrustEngine: any DeviceTrustEngine,
        searchEngine: any SearchEngine,
        biometricAuthProvider: (any BiometricAuthProvider)? = nil
    ) {
        self.cryptoEngine = cryptoEngine
        self.storageEngine = storageEngine
        self.blobStore = blobStore
        self.blobEncryptionEngine = blobEncryptionEngine
        self.eventEngine = eventEngine
        self.deviceTrustEngine = deviceTrustEngine
        self.searchEngine = searchEngine
        self.biometricAuthProvider = biometricAuthProvider
    }
}
