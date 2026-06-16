internal protocol DeviceTrustEngine: Sendable {
    func currentDeviceIdentity() async throws -> DeviceIdentity
    func trustDevice(_ identity: DeviceIdentity, for vaultId: VaultID) async throws
    func trustedDevices(for vaultId: VaultID) async throws -> [DeviceIdentity]
}
