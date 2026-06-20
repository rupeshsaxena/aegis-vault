import SecureVaultKit

protocol LockVaultUsing: Sendable {
    func execute(vaultID: VaultID) async
}

struct LockVaultUseCase: LockVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(vaultID: VaultID) async {
        await vaultEngine.lockVault(id: vaultID)
    }
}
