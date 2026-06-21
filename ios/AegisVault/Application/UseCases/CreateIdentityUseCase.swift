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
        try await vaultEngine.createObject(
            VaultObjectDraft(
                type: .identity,
                metadata: VaultMetadata(
                    title: data.title,
                    category: data.identityType.rawValue,
                    tags: data.tags
                ),
                payload: VaultPayload(
                    notes: data.notes,
                    fields: fields(from: data)
                )
            )
        )
    }

    private func fields(from data: IdentityEditorViewData) -> [String: VaultFieldValue] {
        var fields: [String: VaultFieldValue] = [
            "identityType": .text(data.identityType.rawValue),
            "fullName": .text(data.fullName),
            "documentNumber": .secureText(data.documentNumber)
        ]
        if let issueDate = data.issueDate {
            fields["issueDate"] = .date(issueDate)
        }
        if let expiryDate = data.expiryDate {
            fields["expiryDate"] = .date(expiryDate)
        }
        return fields
    }
}
