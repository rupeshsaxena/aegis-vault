import Foundation

// In-memory infrastructure for the simulator/demo VaultEngine composition.
// All types are internal — only accessible via VaultEngineFactory.makeSimulatorEngine().

actor SimulatorStorageEngine: StorageEngine {
    private var headers: [VaultID: VaultHeaderRecord] = [:]
    private var objects: [VaultObjectID: VaultObjectRecord] = [:]

    func vaultExists() async throws -> Bool {
        !headers.isEmpty
    }

    func createVaultHeader(_ record: VaultHeaderRecord) async throws {
        guard headers.isEmpty else { throw VaultError.vaultAlreadyExists }
        headers[record.vaultId] = record
    }

    func loadVaultHeader() async throws -> VaultHeaderRecord {
        guard let header = headers.values.first else {
            throw VaultError.vaultNotFound(VaultID("primary"))
        }
        return header
    }

    func loadVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord {
        guard let header = headers[vaultId] else {
            throw VaultError.vaultNotFound(vaultId)
        }
        return header
    }

    func readVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord {
        try await loadVaultHeader(vaultId: vaultId)
    }

    func writeVaultHeader(_ record: VaultHeaderRecord) async throws {
        headers[record.vaultId] = record
    }

    func insertObject(_ record: VaultObjectRecord) async throws {
        objects[record.id] = record
    }

    func updateObject(_ record: VaultObjectRecord) async throws {
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

    func loadObject(id: VaultObjectID) async throws -> VaultObjectRecord {
        guard let object = objects[id] else {
            throw VaultError.objectNotFound(id)
        }
        return object
    }

    func readObject(id: VaultObjectID) async throws -> VaultObjectRecord {
        try await loadObject(id: id)
    }

    func writeObject(_ record: VaultObjectRecord) async throws {
        objects[record.id] = record
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
        for object in purged { objects[object.id] = nil }
        return purged
    }

    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord] {
        objects.values
            .filter { $0.vaultId == vaultId }
            .filter { filter.includeDeleted || !$0.isDeleted }
            .filter { filter.types.isEmpty || filter.types.contains($0.type) }
    }
}

actor SimulatorBlobStore: BlobStore {
    func writeBlob(_ data: Data, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        throw VaultError.unsupportedOperation("Blob storage is not available in the simulator engine.")
    }

    func writeBlob(from fileURL: URL, contentType: String, role: BlobRole) async throws -> BlobWriteResult {
        throw VaultError.unsupportedOperation("Blob storage is not available in the simulator engine.")
    }

    func writeEncryptedBlob(
        from fileURL: URL,
        result: EncryptedBlobResult,
        wrappedKey: WrappedKey,
        contentType: String,
        role: BlobRole
    ) async throws -> BlobWriteResult {
        throw VaultError.unsupportedOperation("Blob storage is not available in the simulator engine.")
    }

    func readBlob(id: BlobID) async throws -> Data {
        throw VaultError.unsupportedOperation("Blob storage is not available in the simulator engine.")
    }

    func deleteBlob(id: BlobID) async throws {
        throw VaultError.unsupportedOperation("Blob storage is not available in the simulator engine.")
    }

    func blobExists(id: BlobID) async throws -> Bool { false }

    func listBlobs() async throws -> [BlobRecord] { [] }
}

actor SimulatorEventEngine: EventEngine {
    private var storedEvents: [VaultEvent] = []

    func append(_ event: VaultEvent) async throws {
        storedEvents.append(event)
    }

    func listEvents(for vaultId: VaultID) async throws -> [VaultEvent] {
        storedEvents.filter { $0.vaultId == vaultId }
    }

    func events(for vaultId: VaultID) async throws -> [VaultEvent] {
        try await listEvents(for: vaultId)
    }
}

actor SimulatorDeviceTrustEngine: DeviceTrustEngine {
    private var identities: [VaultID: [DeviceID: DeviceIdentity]] = [:]

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
            publicKey: "simulator-public-key-\(deviceId.rawValue)",
            trustState: .trusted,
            permissions: [.read, .write, .sync, .manageDevices]
        )
        identities[vaultId, default: [:]][deviceId] = identity
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
        identities[vaultId, default: [:]][deviceId] = identity
        return identity
    }

    func trustDevice(
        id deviceId: DeviceID,
        for vaultId: VaultID,
        issuedBy issuingDeviceId: DeviceID,
        permissions: [DevicePermission]
    ) async throws -> TrustCertificate {
        guard var identity = identities[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .trusted
        identity.permissions = permissions
        identities[vaultId, default: [:]][deviceId] = identity
        return TrustCertificate(
            vaultId: vaultId,
            deviceId: deviceId,
            issuedByDeviceId: issuingDeviceId,
            permissions: permissions,
            signature: "simulator-trust-\(vaultId.rawValue)-\(deviceId.rawValue)"
        )
    }

    func revokeDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        guard var identity = identities[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .revoked
        identities[vaultId, default: [:]][deviceId] = identity
    }

    func markDeviceLost(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        guard var identity = identities[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        identity.trustState = .lost
        identities[vaultId, default: [:]][deviceId] = identity
    }

    func listTrustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        identities[vaultId, default: [:]].values
            .filter { $0.trustState == .trusted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func getDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity {
        guard let identity = identities[vaultId]?[deviceId] else {
            throw VaultError.invalidInput("Unknown device.")
        }
        return identity
    }

    func currentDeviceIdentity() async throws -> DeviceIdentity {
        DeviceIdentity(
            id: DeviceID("simulator-device"),
            displayName: "Simulator",
            publicKeyReference: "simulator-key"
        )
    }

    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws {
        identities[vaultId, default: [:]][identity.deviceId] = identity
    }

    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        try await listTrustedDevices(for: vaultId)
    }
}
