internal protocol DeviceTrustEngine: Sendable {
    func createFirstDeviceIdentity(
        deviceId: DeviceID,
        deviceName: String,
        platform: String,
        vaultId: VaultID
    ) async throws -> DeviceIdentity

    func registerPendingDevice(
        deviceId: DeviceID,
        deviceName: String,
        platform: String,
        publicKey: String,
        for vaultId: VaultID
    ) async throws -> DeviceIdentity

    func trustDevice(
        id deviceId: DeviceID,
        for vaultId: VaultID,
        issuedBy issuingDeviceId: DeviceID,
        permissions: [DevicePermission]
    ) async throws -> TrustCertificate

    func revokeDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws
    func markDeviceLost(id deviceId: DeviceID, for vaultId: VaultID) async throws
    func listTrustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity]
    func getDevice(id deviceId: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity

    func currentDeviceIdentity() async throws -> DeviceIdentity
    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws
    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity]
}
