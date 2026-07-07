import Foundation
import SecureVaultKit

protocol UpdateIdentityUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID
}

struct UpdateIdentityUseCase: UpdateIdentityUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(existing: VaultObjectDetail, data: IdentityEditorViewData) async throws -> VaultObjectID {
        let aggregate = IdentityAggregate(data: data)
        let detail = try await vaultEngine.updateObject(
            aggregate.toVaultObjectUpdate(existing: existing)
        )
        return detail.id
    }
}
