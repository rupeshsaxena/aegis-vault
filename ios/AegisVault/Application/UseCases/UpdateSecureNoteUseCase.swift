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
        let aggregate = SecureNoteAggregate(data: data)
        let detail = try await vaultEngine.updateObject(
            aggregate.toVaultObjectUpdate(existing: existing)
        )
        return detail.id
    }
}
