internal protocol DeviceRepository: Sendable {
    func save(_ device: DeviceIdentity, for vaultId: VaultID) async throws
    func load(id: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity
    func list(for vaultId: VaultID) async throws -> [DeviceIdentity]
    func updateTrustState(
        _ state: DeviceTrustState,
        deviceId: DeviceID,
        vaultId: VaultID,
        issuedByDeviceId: DeviceID
    ) async throws
}

internal struct DefaultDeviceRepository: DeviceRepository {
    private let deviceTrustEngine: any DeviceTrustEngine

    init(deviceTrustEngine: any DeviceTrustEngine) {
        self.deviceTrustEngine = deviceTrustEngine
    }

    func save(_ device: DeviceIdentity, for vaultId: VaultID) async throws {
        switch device.trustState {
        case .pending:
            _ = try await deviceTrustEngine.registerPendingDevice(
                deviceId: device.deviceId,
                deviceName: device.deviceName,
                platform: device.platform,
                publicKey: device.publicKey,
                for: vaultId
            )
        case .trusted:
            try await deviceTrustEngine.trustDevice(device, for: vaultId)
        case .revoked:
            try await deviceTrustEngine.revokeDevice(id: device.deviceId, for: vaultId)
        case .lost:
            try await deviceTrustEngine.markDeviceLost(id: device.deviceId, for: vaultId)
        }
    }

    func load(id: DeviceID, for vaultId: VaultID) async throws -> DeviceIdentity {
        try await deviceTrustEngine.getDevice(id: id, for: vaultId)
    }

    func list(for vaultId: VaultID) async throws -> [DeviceIdentity] {
        try await deviceTrustEngine.listTrustedDevices(for: vaultId)
    }

    func updateTrustState(
        _ state: DeviceTrustState,
        deviceId: DeviceID,
        vaultId: VaultID,
        issuedByDeviceId: DeviceID
    ) async throws {
        switch state {
        case .pending:
            throw VaultError.unsupportedOperation("Existing devices cannot transition back to pending.")
        case .trusted:
            _ = try await deviceTrustEngine.trustDevice(
                id: deviceId,
                for: vaultId,
                issuedBy: issuedByDeviceId,
                permissions: [.read, .write, .sync]
            )
        case .revoked:
            try await deviceTrustEngine.revokeDevice(id: deviceId, for: vaultId)
        case .lost:
            try await deviceTrustEngine.markDeviceLost(id: deviceId, for: vaultId)
        }
    }
}
