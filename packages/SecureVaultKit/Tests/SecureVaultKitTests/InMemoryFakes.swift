import Foundation
@testable import SecureVaultKit

actor InMemoryCryptoEngine: CryptoEngine {
    private var encryptedPayloads: [String: VaultPayload] = [:]

    func deriveVaultKey(for vaultId: VaultID, using method: UnlockMethod) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "key-\(vaultId.rawValue)-\(method.rawValue)")
    }

    func wrapKey(_ key: SymmetricKeyMaterial, for deviceId: DeviceID) async throws -> WrappedKey {
        WrappedKey(keyReference: key.reference, wrappedByDeviceId: deviceId)
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

    func readVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord {
        guard let header = headers[vaultId] else {
            throw VaultError.vaultNotFound(vaultId)
        }
        return header
    }

    func writeVaultHeader(_ record: VaultHeaderRecord) async throws {
        headers[record.vaultId] = record
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

    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord] {
        objects.values
            .filter { $0.vaultId == vaultId }
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
    }
}

actor InMemoryBlobStore: BlobStore {
    private var blobs: [BlobID: Data] = [:]
    private var contentTypes: [BlobID: String] = [:]

    func writeBlob(_ data: Data, contentType: String) async throws -> BlobWriteResult {
        let id = BlobID()
        blobs[id] = data
        contentTypes[id] = contentType
        return BlobWriteResult(id: id, byteCount: data.count, contentType: contentType)
    }

    func readBlob(id: BlobID) async throws -> Data {
        guard let data = blobs[id] else {
            throw VaultError.unsupportedOperation("Blob not found in in-memory fake.")
        }
        return data
    }

    func deleteBlob(id: BlobID) async throws {
        blobs[id] = nil
        contentTypes[id] = nil
    }
}

actor InMemoryEventEngine: EventEngine {
    private var storedEvents: [VaultEvent] = []

    func append(_ event: VaultEvent) async throws {
        storedEvents.append(event)
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

    func indexObject(_ object: VaultObjectRecord) async throws {
        indexedObjectIDsByVault[object.vaultId, default: []].insert(object.id)
    }

    func removeObject(id: VaultObjectID) async throws {
        for vaultId in indexedObjectIDsByVault.keys {
            indexedObjectIDsByVault[vaultId]?.remove(id)
        }
    }

    func search(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectID] {
        Array(indexedObjectIDsByVault[vaultId, default: []])
    }
}

func makeInMemoryConfiguration() -> VaultKitConfiguration {
    VaultKitConfiguration(
        cryptoEngine: InMemoryCryptoEngine(),
        storageEngine: InMemoryStorageEngine(),
        blobStore: InMemoryBlobStore(),
        eventEngine: InMemoryEventEngine(),
        deviceTrustEngine: InMemoryDeviceTrustEngine(),
        searchEngine: InMemorySearchEngine()
    )
}
