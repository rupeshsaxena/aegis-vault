import Foundation
import SecureVaultKit

struct CardAggregate: VaultObjectAggregate {
    let title: String
    let cardType: CardType
    let cardholderName: String
    let cardNumber: String
    let expiryMonth: Int?
    let expiryYear: Int?
    let issuer: String
    let notes: String
    let tags: [String]

    var objectType: VaultObjectType { .card }

    init(data: CardEditorViewData) {
        self.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cardType = data.cardType
        self.cardholderName = data.cardholderName
        self.cardNumber = data.cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.expiryMonth = data.expiryMonth
        self.expiryYear = data.expiryYear
        self.issuer = data.issuer
        self.notes = data.notes
        self.tags = data.tags
    }

    func validateInvariants() throws {
        guard !title.isEmpty else {
            throw ValidationError.missingTitle
        }
        guard !cardType.requiresCardNumber || !cardNumber.isEmpty else {
            throw ValidationError.missingRequiredField("cardNumber")
        }
    }

    func toVaultObjectDraft() throws -> VaultObjectDraft {
        try validateInvariants()
        return VaultObjectDraft(
            type: objectType,
            metadata: VaultMetadata(
                title: title,
                category: cardType.rawValue,
                tags: tags
            ),
            payload: VaultPayload(
                notes: notes,
                fields: fields()
            )
        )
    }

    func toVaultObjectUpdate(existing: VaultObjectDetail) throws -> VaultObjectUpdate {
        try validateInvariants()
        guard existing.type == objectType else {
            throw ValidationError.unsupportedType(existing.type.rawValue)
        }
        var metadata = existing.metadata
        metadata.title = title
        metadata.category = cardType.rawValue
        metadata.tags = tags
        metadata.updatedAt = Date()
        var payload = existing.payload
        payload.notes = notes
        payload.fields.merge(fields()) { _, new in new }
        return VaultObjectUpdate(
            objectId: existing.id,
            metadata: metadata,
            payload: payload
        )
    }

    private func fields() -> [String: VaultFieldValue] {
        var fields: [String: VaultFieldValue] = [
            "cardType": .text(cardType.rawValue),
            "cardholderName": .text(cardholderName),
            "cardNumber": .secureText(cardNumber),
            "issuer": .text(issuer)
        ]
        if let expiryMonth {
            fields["expiryMonth"] = .number(Double(expiryMonth))
        }
        if let expiryYear {
            fields["expiryYear"] = .number(Double(expiryYear))
        }
        return fields
    }
}
