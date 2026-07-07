import SecureVaultKit

protocol CreateCardUsing: Sendable {
    func execute(data: CardEditorViewData) async throws -> VaultObjectID
}

struct CreateCardUseCase: CreateCardUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(data: CardEditorViewData) async throws -> VaultObjectID {
        let aggregate = CardAggregate(data: data)
        return try await vaultEngine.createObject(aggregate.toVaultObjectDraft())
    }
}
