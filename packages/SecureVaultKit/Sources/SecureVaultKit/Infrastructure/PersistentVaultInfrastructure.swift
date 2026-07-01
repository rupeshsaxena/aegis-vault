import Foundation

internal actor SQLiteDeviceTrustEngine: DeviceTrustEngine {
    private let storageEngine: SQLiteStorageEngine

    init(storageEngine: SQLiteStorageEngine) {
        self.storageEngine = storageEngine
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
            publicKey: "local-public-key-\(deviceId.rawValue)",
            trustState: .trusted,
            permissions: [.read, .write, .sync, .manageDevices]
        )
        try await storageEngine.upsertTrustedDevice(identity, vaultId: vaultId)
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
        try await storageEngine.upsertTrustedDevice(identity, vaultId: vaultId)
        return identity
    }

    func trustDevice(
        id deviceId: DeviceID,
        for vaultId: VaultID,
        issuedBy issuingDeviceId: DeviceID,
        permissions: [DevicePermission]
    ) async throws -> TrustCertificate {
        var identity = try await getDevice(id: deviceId, for: vaultId)
        identity.trustState = .trusted
        identity.permissions = permissions
        try await storageEngine.upsertTrustedDevice(identity, vaultId: vaultId)
        return TrustCertificate(
            vaultId: vaultId,
            deviceId: deviceId,
            issuedByDeviceId: issuingDeviceId,
            permissions: permissions,
            signature: "local-trust-\(vaultId.rawValue)-\(deviceId.rawValue)"
        )
    }

    func revokeDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        var identity = try await getDevice(id: deviceId, for: vaultId)
        identity.trustState = .revoked
        try await storageEngine.upsertTrustedDevice(identity, vaultId: vaultId)
    }

    func markDeviceLost(id deviceId: DeviceID, for vaultId: VaultID) async throws {
        var identity = try await getDevice(id: deviceId, for: vaultId)
        identity.trustState = .lost
        try await storageEngine.upsertTrustedDevice(identity, vaultId: vaultId)
    }

    func listTrustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        try await storageEngine.listPersistedDevices(for: vaultId)
            .filter { $0.trustState == .trusted }
    }

    func getDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity {
        guard let identity = try await storageEngine.listPersistedDevices(for: vaultId)
            .first(where: { $0.deviceId == deviceId }) else {
            throw VaultError.invalidInput("Unknown device.")
        }
        return identity
    }

    func currentDeviceIdentity() async throws -> DeviceIdentity {
        DeviceIdentity(
            id: DeviceID("local-device"),
            displayName: "Local Device",
            publicKeyReference: "local-public-key"
        )
    }

    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws {
        var trustedIdentity = identity
        trustedIdentity.trustState = .trusted
        try await storageEngine.upsertTrustedDevice(trustedIdentity, vaultId: vaultId)
    }

    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        try await listTrustedDevices(for: vaultId)
    }
}
