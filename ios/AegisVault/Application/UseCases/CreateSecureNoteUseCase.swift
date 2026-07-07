import SecureVaultKit

protocol CreateSecureNoteUsing: Sendable {
    func execute(data: SecureNoteEditorViewData) async throws -> VaultObjectID
}

struct CreateSecureNoteUseCase: CreateSecureNoteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        let aggregate = SecureNoteAggregate(data: data)
        return try await vaultEngine.createObject(aggregate.toVaultObjectDraft())
    }
}
