import SecureVaultKit

protocol CreateVaultUsing: Sendable {
    func execute(
        name: String,
        deviceID: DeviceID,
        unlockMethod: UnlockMethod
    ) async throws -> VaultID
}

struct CreateVaultUseCase: CreateVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(
        name: String,
        deviceID: DeviceID,
        unlockMethod: UnlockMethod
    ) async throws -> VaultID {
        try await vaultEngine.createVault(
            config: VaultCreationConfig(
                name: name,
                deviceID: deviceID,
                unlockMethod: unlockMethod
            )
        )
    }
}
