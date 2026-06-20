import SecureVaultKit

protocol UnlockVaultUsing: Sendable {
    func execute(method: UnlockMethod) async throws
}

struct UnlockVaultUseCase: UnlockVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(method: UnlockMethod) async throws {
        try await vaultEngine.unlockVault(method: method)
    }
}
