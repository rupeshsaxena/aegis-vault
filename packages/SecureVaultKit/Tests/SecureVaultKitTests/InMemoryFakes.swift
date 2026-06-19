import Foundation
@testable import SecureVaultKit

actor InMemoryCryptoEngine: CryptoEngine {
    private var encryptedPayloads: [String: VaultPayload] = [:]
    private var encryptedMetadata: [String: VaultMetadata] = [:]
    private var keyCounter = 0

    func generateKey() async throws -> SymmetricKeyMaterial {
        keyCounter += 1
        return SymmetricKeyMaterial(
            keyId: KeyIdentifier("in-memory-key-\(keyCounter)"),
            data: Data("in-memory-key-material-\(keyCounter)".utf8)
        )
    }

    func encrypt(_ plaintext: Data, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        EncryptedEnvelope(
            version: 1,
            algorithm: .xChaCha20Poly1305,
            keyId: key.keyId,
            nonce: Data("in-memory-nonce-\(key.keyId.rawValue)".utf8),
            ciphertext: Data("in-memory-ciphertext:\(plaintext.base64EncodedString())".utf8)
        )
    }

    func decrypt(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> Data {
        guard envelope.keyId == key.keyId,
              let ciphertext = String(data: envelope.ciphertext, encoding: .utf8),
              ciphertext.hasPrefix("in-memory-ciphertext:") else {
            throw CryptoError.invalidEnvelope
        }
        let encodedPlaintext = String(ciphertext.dropFirst("in-memory-ciphertext:".count))
        guard let plaintext = Data(base64Encoded: encodedPlaintext) else {
            throw CryptoError.invalidEnvelope
        }
        return plaintext
    }

    func wrapKey(_ key: SymmetricKeyMaterial, using wrappingKey: SymmetricKeyMaterial) async throws -> WrappedKey {
        WrappedKey(
            keyId: key.keyId,
            wrappingKeyId: wrappingKey.keyId,
            wrappedData: Data("in-memory-wrapped-key:\(key.data.base64EncodedString())".utf8),
            algorithm: .xChaCha20Poly1305
        )
    }

    func unwrapKey(_ wrappedKey: WrappedKey, using wrappingKey: SymmetricKeyMaterial) async throws -> SymmetricKeyMaterial {
        guard wrappedKey.wrappingKeyId == wrappingKey.keyId,
              let wrappedData = String(data: wrappedKey.wrappedData, encoding: .utf8),
              wrappedData.hasPrefix("in-memory-wrapped-key:") else {
            throw CryptoError.invalidWrappedKey
        }
        let encodedKeyMaterial = String(wrappedData.dropFirst("in-memory-wrapped-key:".count))
        guard let keyMaterial = Data(base64Encoded: encodedKeyMaterial) else {
            throw CryptoError.invalidWrappedKey
        }
        return SymmetricKeyMaterial(keyId: wrappedKey.keyId, data: keyMaterial)
    }

    func generateRootVaultKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-root-vault-key-\(vaultId.rawValue)")
    }

    func generateVaultEncryptionKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-vault-encryption-key-\(vaultId.rawValue)")
    }

    func generateItemKey(for objectId: VaultObjectID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-item-key-\(objectId.rawValue)")
    }

    func deriveVaultKey(for vaultId: VaultID, using method: UnlockMethod) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "key-\(vaultId.rawValue)-\(method.fakeIdentifier)")
    }

    func wrapKey(_ key: SymmetricKeyMaterial, for deviceId: DeviceID) async throws -> WrappedKey {
        WrappedKey(keyReference: key.reference, wrappedByDeviceId: deviceId)
    }

    func wrapItemKey(_ key: SymmetricKeyMaterial, usingVaultEncryptionKey keyReference: String) async throws -> WrappedKey {
        WrappedKey(keyReference: key.reference, wrappingKeyReference: keyReference)
    }

    func unwrapItemKey(_ wrappedKey: WrappedKey, usingVaultEncryptionKey keyReference: String) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: wrappedKey.keyReference)
    }

    func encryptMetadata(_ metadata: VaultMetadata, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let reference = "encrypted-metadata-\(encryptedMetadata.count + 1)"
        encryptedMetadata[reference] = metadata
        return EncryptedEnvelope(
            algorithm: "in-memory.fake.metadata",
            keyReference: key.reference,
            ciphertextReference: reference
        )
    }

    func decryptMetadata(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> VaultMetadata {
        encryptedMetadata[envelope.ciphertextReference] ?? VaultMetadata(title: "")
    }

    func encryptPayload(_ payload: VaultPayload, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let reference = "payload-\(encryptedPayloads.count + 1)"
        encryptedPayloads[reference] = payload
        return EncryptedEnvelope(
            algorithm: "in-memory.fake",
            keyReference: key.reference,
            ciphertextReference: reference
        )
    }

    func decryptPayload(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> VaultPayload {
        encryptedPayloads[envelope.ciphertextReference] ?? VaultPayload()
    }
}

actor InMemoryStorageEngine: StorageEngine {
    private var headers: [VaultID: VaultHeaderRecord] = [:]
    private var objects: [VaultObjectID: VaultObjectRecord] = [:]
    private var shouldFailNextInsert = false
    private var shouldFailNextUpdate = false

    func vaultExists() async throws -> Bool {
        !headers.isEmpty
    }

    func createVaultHeader(_ record: VaultHeaderRecord) async throws {
        guard headers.isEmpty else {
            throw VaultError.vaultAlreadyExists
        }
        headers[record.vaultId] = record
    }

    func loadVaultHeader() async throws -> VaultHeaderRecord {
        guard let header = headers.values.first else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        return header
    }

    func loadVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord {
        try await readVaultHeader(vaultId: vaultId)
    }

    func readVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord {
        guard let header = headers[vaultId] else {
            throw VaultError.vaultNotFound(vaultId)
        }
        return header
    }

    func writeVaultHeader(_ record: VaultHeaderRecord) async throws {
        headers[record.vaultId] = record
    }

    func insertObject(_ record: VaultObjectRecord) async throws {
        if shouldFailNextInsert {
            shouldFailNextInsert = false
            throw VaultError.unsupportedOperation("Injected storage insert failure.")
        }
        objects[record.id] = record
    }

    func updateObject(_ record: VaultObjectRecord) async throws {
        if shouldFailNextUpdate {
            shouldFailNextUpdate = false
            throw VaultError.unsupportedOperation("Injected storage update failure.")
        }
        guard objects[record.id] != nil else {
            throw VaultError.objectNotFound(record.id)
        }
        objects[record.id] = record
    }

    func deleteObject(id: VaultObjectID) async throws {
        guard objects.removeValue(forKey: id) != nil else {
            throw VaultError.objectNotFound(id)
        }
    }

    func failNextUpdate() {
        shouldFailNextUpdate = true
    }

    func failNextInsert() {
        shouldFailNextInsert = true
    }

    func loadObject(id: VaultObjectID) async throws -> VaultObjectRecord {
        try await readObject(id: id)
    }

    func listObjects(in vaultId: VaultID) async throws -> [VaultObjectRecord] {
        try await listObjects(in: vaultId, includeDeleted: true)
    }

    func listObjects(in vaultId: VaultID, includeDeleted: Bool) async throws -> [VaultObjectRecord] {
        objects.values
            .filter { $0.vaultId == vaultId }
            .filter { includeDeleted || !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func readObject(id: VaultObjectID) async throws -> VaultObjectRecord {
        guard let object = objects[id] else {
            throw VaultError.objectNotFound(id)
        }
        return object
    }

    func writeObject(_ record: VaultObjectRecord) async throws {
        objects[record.id] = record
    }

    func markDeleted(id: VaultObjectID, at deletedAt: Date) async throws -> VaultObjectRecord {
        guard var object = objects[id] else {
            throw VaultError.objectNotFound(id)
        }
        object.isDeleted = true
        object.deletedAt = deletedAt
        object.updatedAt = deletedAt
        objects[id] = object
        return object
    }

    func restoreDeleted(id: VaultObjectID) async throws -> VaultObjectRecord {
        guard var object = objects[id] else {
            throw VaultError.objectNotFound(id)
        }
        object.isDeleted = false
        object.deletedAt = nil
        object.updatedAt = Date()
        objects[id] = object
        return object
    }

    func purgeDeleted(in vaultId: VaultID, olderThan cutoff: Date) async throws -> [VaultObjectRecord] {
        let purged = objects.values.filter { object in
            guard object.vaultId == vaultId, object.isDeleted, let deletedAt = object.deletedAt else {
                return false
            }
            return deletedAt < cutoff
        }
        for object in purged {
            objects[object.id] = nil
        }
        return purged
    }

    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord] {
        objects.values
            .filter { $0.vaultId == vaultId }
            .filter { filter.includeDeleted || !$0.isDeleted }
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
    }
}

actor InMemoryBlobStore: BlobStore {
    private var blobs: [BlobID: Data] = [:]
    private var records: [BlobID: BlobRecord] = [:]
    private var shouldFailNextWrite = false
    private var shouldFailNextDelete = false

    func writeBlob(_ data: Data, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        if shouldFailNextWrite {
            shouldFailNextWrite = false
            throw VaultError.unsupportedOperation("Injected blob write failure.")
        }
        let id = BlobID()
        let record = BlobRecord(
            id: id,
            role: role,
            contentType: contentType,
            byteCount: data.count,
            encryptionMetadata: .fakeProtected(keyReference: "fake-in-memory-blob-key")
        )
        blobs[id] = FakeBlobProtection.protect(data)
        records[id] = record
        return BlobWriteResult(id: id, byteCount: data.count, contentType: contentType, record: record)
    }

    func writeBlob(from fileURL: URL, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        let data = try Data(contentsOf: fileURL)
        return try await writeBlob(data, contentType: contentType, role: role)
    }

    func writeEncryptedBlob(
        from fileURL: URL,
        result: EncryptedBlobResult,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        if shouldFailNextWrite {
            shouldFailNextWrite = false
            throw VaultError.unsupportedOperation("Injected blob write failure.")
        }
        let data = try Data(contentsOf: fileURL)
        let record = BlobRecord(
            id: result.blobId,
            role: role,
            contentType: contentType,
            byteCount: Int(result.originalSizeBytes),
            encryptionMetadata: .encryptedBlob(result),
            createdAt: result.createdAt
        )
        blobs[result.blobId] = FakeBlobProtection.protect(data)
        records[result.blobId] = record
        return BlobWriteResult(
            id: result.blobId,
            byteCount: Int(result.originalSizeBytes),
            contentType: contentType,
            record: record
        )
    }

    func readBlob(id: BlobID) async throws -> Data {
        guard let data = blobs[id] else {
            throw VaultError.unsupportedOperation("Blob not found in in-memory fake.")
        }
        return FakeBlobProtection.unprotect(data)
    }

    func deleteBlob(id: BlobID) async throws {
        if shouldFailNextDelete {
            shouldFailNextDelete = false
            throw VaultError.unsupportedOperation("Injected blob delete failure.")
        }
        blobs[id] = nil
        records[id] = nil
    }

    func blobExists(id: BlobID) async throws -> Bool {
        blobs[id] != nil
    }

    func listBlobs() async throws -> [BlobRecord] {
        records.values.sorted { $0.createdAt < $1.createdAt }
    }

    func failNextWrite() {
        shouldFailNextWrite = true
    }

    func failNextDelete() {
        shouldFailNextDelete = true
    }
}

actor InMemoryEventEngine: EventEngine {
    private var storedEvents: [VaultEvent] = []
    private var shouldFailNextAppend = false

    func append(_ event: VaultEvent) async throws {
        if shouldFailNextAppend {
            shouldFailNextAppend = false
            throw VaultError.unsupportedOperation("Injected event append failure.")
        }
        storedEvents.append(event)
    }

    func failNextAppend() {
        shouldFailNextAppend = true
    }

    func listEvents(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await events(for: vaultId)
    }

    func events(for vaultId: VaultID) async throws -> [VaultEvent] {
        storedEvents.filter { $0.vaultId == vaultId }
    }
}

actor InMemoryDeviceTrustEngine: DeviceTrustEngine {
    private var currentIdentity: DeviceIdentity
    private var identitiesByVault: [VaultID: [DeviceID: DeviceIdentity]] = [:]
    private var certificatesByVault: [VaultID: [DeviceID: TrustCertificate]] = [:]
    private let eventEngine: (any EventEngine)?

    init(currentIdentity: DeviceIdentity = DeviceIdentity(
        id: DeviceID("test-device"),
        displayName: "Test Device",
        publicKeyReference: "test-public-key"
    ), eventEngine: (any EventEngine)? = nil) {
        self.currentIdentity = currentIdentity
        self.eventEngine = eventEngine
    }

    func createFirstDeviceIdentity(
        deviceId: DeviceID,
        deviceName: String,
        platform: String,
        vaultId: VaultID
    ) async throws -> DeviceIdentity {
        let identity = DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: platform,
            publicKey: "fake-device-public-key-\(deviceId.rawValue)",
            trustState: .trusted,
            permissions: [.read, .write, .sync, .manageDevices]
        )
        let certificate = TrustCertificate(
            vaultId: vaultId,
            deviceId: deviceId,
            issuedByDeviceId: deviceId,
            permissions: identity.permissions,
            signature: "fake-trust-signature-\(vaultId.rawValue)-\(deviceId.rawValue)"
        )
        identitiesByVault[vaultId, default: [:]][deviceId] = identity
        certificatesByVault[vaultId, default: [:]][deviceId] = certificate
        currentIdentity = identity
        try await append(.deviceRegistered(vaultId: vaultId, deviceId: deviceId))
        try await append(.deviceTrusted(vaultId: vaultId, deviceId: deviceId))
        return identity
    }

    func registerPendingDevice(
        deviceId: DeviceID,
        deviceName: String,
        platform: String,
        publicKey: String,
        for vaultId: VaultID
    ) async throws -> DeviceIdentity {
        let identity = DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: platform,
            publicKey: publicKey,
            trustState: .pending
        )
        identitiesByVault[vaultId, default: [:]][deviceId] = identity
        try await append(.deviceRegistered(vaultId: vaultId, deviceId: deviceId))
        return identity
    }

    func trustDevice(
        id deviceId: DeviceID,
        for vaultId: VaultID,
        issuedBy issuingDeviceId: DeviceID,
        permissions: [DevicePermission]
    ) async throws -> TrustCertificate {
        guard var identity = identitiesByVault[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .trusted
        identity.permissions = permissions
        identitiesByVault[vaultId, default: [:]][deviceId] = identity
        let certificate = TrustCertificate(
            vaultId: vaultId,
            deviceId: deviceId,
            issuedByDeviceId: issuingDeviceId,
            permissions: permissions,
            signature: "fake-trust-signature-\(vaultId.rawValue)-\(deviceId.rawValue)"
        )
        certificatesByVault[vaultId, default: [:]][deviceId] = certificate
        try await append(.deviceTrusted(vaultId: vaultId, deviceId: deviceId))
        return certificate
    }

    func revokeDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        guard var identity = identitiesByVault[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .revoked
        identitiesByVault[vaultId, default: [:]][deviceId] = identity
        certificatesByVault[vaultId]?[deviceId] = nil
        try await append(.deviceRevoked(vaultId: vaultId, deviceId: deviceId))
    }

    func markDeviceLost(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        guard var identity = identitiesByVault[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .lost
        identitiesByVault[vaultId, default: [:]][deviceId] = identity
        certificatesByVault[vaultId]?[deviceId] = nil
        try await append(.deviceLost(vaultId: vaultId, deviceId: deviceId))
    }

    func listTrustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        identitiesByVault[vaultId, default: [:]]
            .values
            .filter { $0.trustState == .trusted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func getDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity {
        guard let identity = identitiesByVault[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        return identity
    }

    func currentDeviceIdentity() async throws -> DeviceIdentity {
        currentIdentity
    }

    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws {
        identitiesByVault[vaultId, default: [:]][identity.deviceId] = identity
        if identity.trustState == .trusted {
            let certificate = TrustCertificate(
                vaultId: vaultId,
                deviceId: identity.deviceId,
                issuedByDeviceId: identity.deviceId,
                permissions: identity.permissions,
                signature: "fake-trust-signature-\(vaultId.rawValue)-\(identity.deviceId.rawValue)"
            )
            certificatesByVault[vaultId, default: [:]][identity.deviceId] = certificate
        }
    }

    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        try await listTrustedDevices(for: vaultId)
    }

    private func append(_ event: VaultEvent) async throws {
        try await eventEngine?.append(event)
    }
}

func makeInMemoryConfiguration(
    cryptoEngine: InMemoryCryptoEngine = InMemoryCryptoEngine(),
    storageEngine: InMemoryStorageEngine = InMemoryStorageEngine(),
    blobStore: InMemoryBlobStore = InMemoryBlobStore(),
    blobEncryptionEngine: any BlobEncryptionEngine = FakeBlobEncryptionEngine(),
    eventEngine: InMemoryEventEngine = InMemoryEventEngine(),
    deviceTrustEngine: InMemoryDeviceTrustEngine = InMemoryDeviceTrustEngine(),
    searchEngine: InMemorySearchEngine = InMemorySearchEngine()
) -> VaultKitConfiguration {
    VaultKitConfiguration(
        cryptoEngine: cryptoEngine,
        storageEngine: storageEngine,
        blobStore: blobStore,
        blobEncryptionEngine: blobEncryptionEngine,
        eventEngine: eventEngine,
        deviceTrustEngine: deviceTrustEngine,
        searchEngine: searchEngine
    )
}
