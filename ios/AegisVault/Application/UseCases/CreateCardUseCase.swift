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
        try await vaultEngine.createObject(
            VaultObjectDraft(
                type: .card,
                metadata: VaultMetadata(
                    title: data.title,
                    category: data.cardType.rawValue,
                    tags: data.tags
                ),
                payload: VaultPayload(
                    notes: data.notes,
                    fields: fields(from: data)
                )
            )
        )
    }

    private func fields(from data: CardEditorViewData) -> [String: VaultFieldValue] {
        var fields: [String: VaultFieldValue] = [
            "cardType": .text(data.cardType.rawValue),
            "cardholderName": .text(data.cardholderName),
            "cardNumber": .secureText(data.cardNumber),
            "issuer": .text(data.issuer)
        ]
        if let expiryMonth = data.expiryMonth {
            fields["expiryMonth"] = .number(Double(expiryMonth))
        }
        if let expiryYear = data.expiryYear {
            fields["expiryYear"] = .number(Double(expiryYear))
        }
        return fields
    }
}
