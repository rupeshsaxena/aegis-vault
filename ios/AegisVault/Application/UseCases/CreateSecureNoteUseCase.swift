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
        try await vaultEngine.createObject(
            VaultObjectDraft(
                type: .secureNote,
                metadata: VaultMetadata(title: data.title, tags: data.tags),
                payload: VaultPayload(notes: data.content)
            )
        )
    }
}
