import SecureVaultKit

protocol CreateIdentityUsing: Sendable {
    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID
}

struct CreateIdentityUseCase: CreateIdentityUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(data: IdentityEditorViewData) async throws -> VaultObjectID {
        let aggregate = IdentityAggregate(data: data)
        return try await vaultEngine.createObject(aggregate.toVaultObjectDraft())
    }
}
