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
        guard existing.type == .card else {
            throw VaultError.invalidInput("Only card objects can be edited by this use case.")
        }

        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.cardType.rawValue
        metadata.tags = data.tags
        metadata.updatedAt = Date()

        var payload = existing.payload
        payload.notes = data.notes
        payload.fields["cardType"] = .text(data.cardType.rawValue)
        payload.fields["cardholderName"] = .text(data.cardholderName)
        payload.fields["cardNumber"] = .secureText(data.cardNumber)
        payload.fields["expiryMonth"] = data.expiryMonth.map { .number(Double($0)) }
        payload.fields["expiryYear"] = data.expiryYear.map { .number(Double($0)) }
        payload.fields["issuer"] = .text(data.issuer)

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
