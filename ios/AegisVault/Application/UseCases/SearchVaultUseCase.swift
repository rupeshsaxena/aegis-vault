import SecureVaultKit

protocol SearchVaultUsing: Sendable {
    func execute(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

struct SearchVaultUseCase: SearchVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(
        query: String,
        filter: VaultObjectFilter = VaultObjectFilter()
    ) async throws -> [VaultObjectSummary] {
        try await vaultEngine.searchObjects(query: query, filter: filter)
    }
}
