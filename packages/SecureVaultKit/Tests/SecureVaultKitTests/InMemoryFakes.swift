import Foundation
@testable import SecureVaultKit

actor InMemoryCryptoEngine: CryptoEngine {
    private var encryptedPayloads: [String: VaultPayload] = [:]
    private var encryptedMetadata: [String: VaultMetadata] = [:]

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

    func failNextUpdate() {
        shouldFailNextUpdate = true
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
    private let currentIdentity: DeviceIdentity
    private var identitiesByVault: [VaultID: [DeviceIdentity]] = [:]

    init(currentIdentity: DeviceIdentity = DeviceIdentity(
        id: DeviceID("test-device"),
        displayName: "Test Device",
        publicKeyReference: "test-public-key"
    )) {
        self.currentIdentity = currentIdentity
    }

    func currentDeviceIdentity() async throws -> DeviceIdentity {
        currentIdentity
    }

    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws {
        identitiesByVault[vaultId, default: []].append(identity)
    }

    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        identitiesByVault[vaultId, default: []]
    }
}

actor InMemorySearchEngine: SearchEngine {
    private var indexedObjectIDsByVault: [VaultID: Set<VaultObjectID>] = [:]
    private var summariesByID: [VaultObjectID: VaultObjectSummary] = [:]

    func index(_ summary: VaultObjectSummary) async throws {
        summariesByID[summary.id] = summary
        guard let vaultId = summary.vaultId else { return }
        indexedObjectIDsByVault[vaultId, default: []].insert(summary.id)
    }

    func remove(objectId: VaultObjectID) async throws {
        summariesByID[objectId] = nil
        for vaultId in indexedObjectIDsByVault.keys {
            indexedObjectIDsByVault[vaultId]?.remove(objectId)
        }
    }

    func search(query: String) async throws -> [VaultObjectSummary] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return summariesByID.values
            .filter { !$0.isDeleted }
            .filter { summary in
                guard !normalizedQuery.isEmpty else { return true }
                return summary.title.lowercased().contains(normalizedQuery)
                    || summary.tags.contains { $0.lowercased().contains(normalizedQuery) }
                    || summary.type.rawValue.lowercased().contains(normalizedQuery)
            }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    func all() async throws -> [VaultObjectSummary] {
        try await search(query: "")
    }

    func rebuild(for objects: [VaultObjectRecord]) async throws {
        indexedObjectIDsByVault = [:]
        summariesByID = summariesByID.filter { _, summary in
            objects.contains { $0.id == summary.id }
        }
        for object in objects {
            indexedObjectIDsByVault[object.vaultId, default: []].insert(object.id)
        }
    }

    func clear() async {
        indexedObjectIDsByVault = [:]
        summariesByID = [:]
    }

    func indexSummary(_ summary: VaultObjectSummary) async throws {
        try await index(summary)
    }

    func listSummaries(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        indexedObjectIDsByVault[vaultId, default: []]
            .compactMap { summariesByID[$0] }
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
            .filter { filter.includeDeleted || !$0.isDeleted }
            .filter { summary in
                guard let query = filter.query, !query.isEmpty else { return true }
                return summary.title.localizedCaseInsensitiveContains(query)
                    || (summary.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
            }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    func indexObject(_ object: VaultObjectRecord) async throws {
        indexedObjectIDsByVault[object.vaultId, default: []].insert(object.id)
    }

    func removeObject(id: VaultObjectID) async throws {
        try await remove(objectId: id)
    }

    func search(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectID] {
        Array(indexedObjectIDsByVault[vaultId, default: []])
    }
}

func makeInMemoryConfiguration(
    cryptoEngine: InMemoryCryptoEngine = InMemoryCryptoEngine(),
    storageEngine: InMemoryStorageEngine = InMemoryStorageEngine(),
    blobStore: InMemoryBlobStore = InMemoryBlobStore(),
    eventEngine: InMemoryEventEngine = InMemoryEventEngine(),
    deviceTrustEngine: InMemoryDeviceTrustEngine = InMemoryDeviceTrustEngine(),
    searchEngine: InMemorySearchEngine = InMemorySearchEngine()
) -> VaultKitConfiguration {
    VaultKitConfiguration(
        cryptoEngine: cryptoEngine,
        storageEngine: storageEngine,
        blobStore: blobStore,
        eventEngine: eventEngine,
        deviceTrustEngine: deviceTrustEngine,
        searchEngine: searchEngine
    )
}
