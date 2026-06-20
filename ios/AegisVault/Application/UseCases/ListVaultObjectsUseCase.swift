import SecureVaultKit

protocol ListVaultObjectsUsing: Sendable {
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

struct ListVaultObjectsUseCase: ListVaultObjectsUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(filter: VaultObjectFilter = VaultObjectFilter()) async throws -> [VaultObjectSummary] {
        try await vaultEngine.listObjects(filter: filter)
    }
}
