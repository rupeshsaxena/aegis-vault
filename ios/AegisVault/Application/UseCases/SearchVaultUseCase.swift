import SecureVaultKit

protocol SearchVaultUsing: Sendable {
    func execute(query: String) async throws -> [VaultObjectSummary]
}

struct SearchVaultUseCase: SearchVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(query: String) async throws -> [VaultObjectSummary] {
        try await vaultEngine.searchObjects(query: query)
    }
}
