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
        guard existing.type == .identity else {
            throw VaultError.invalidInput("Only identity objects can be edited by this use case.")
        }

        var metadata = existing.metadata
        metadata.title = data.title
        metadata.category = data.identityType.rawValue
        metadata.tags = data.tags
        metadata.updatedAt = Date()

        var payload = existing.payload
        payload.notes = data.notes
        payload.fields["identityType"] = .text(data.identityType.rawValue)
        payload.fields["fullName"] = .text(data.fullName)
        payload.fields["documentNumber"] = .secureText(data.documentNumber)
        payload.fields["issueDate"] = data.issueDate.map(VaultFieldValue.date)
        payload.fields["expiryDate"] = data.expiryDate.map(VaultFieldValue.date)

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
