import Foundation
import SecureVaultKit

protocol UpdateSecureNoteUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID
}

struct UpdateSecureNoteUseCase: UpdateSecureNoteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(existing: VaultObjectDetail, data: SecureNoteEditorViewData) async throws -> VaultObjectID {
        guard existing.type == .secureNote else {
            throw VaultError.invalidInput("Only secure notes can be edited by this use case.")
        }
        var metadata = existing.metadata
        metadata.title = data.title
        metadata.tags = data.tags
        metadata.updatedAt = Date()
        var payload = existing.payload
        payload.notes = data.content
        let detail = try await vaultEngine.updateObject(
            VaultObjectUpdate(
                objectId: existing.id,
                metadata: metadata,
                payload: payload
            )
        )
        return detail.id
    }
}
