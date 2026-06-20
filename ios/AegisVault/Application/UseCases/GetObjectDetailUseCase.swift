import SecureVaultKit

protocol GetObjectDetailUsing: Sendable {
    func execute(id: VaultObjectID) async throws -> VaultObjectDetail
}

struct GetObjectDetailUseCase: GetObjectDetailUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await vaultEngine.getObjectDetail(id: id)
    }
}
