import Foundation
import SecureVaultKit

protocol UpdateCardUsing: Sendable {
    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID
}

struct UpdateCardUseCase: UpdateCardUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(existing: VaultObjectDetail, data: CardEditorViewData) async throws -> VaultObjectID {
        let aggregate = CardAggregate(data: data)
        let detail = try await vaultEngine.updateObject(
            aggregate.toVaultObjectUpdate(existing: existing)
        )
        return detail.id
    }
}
