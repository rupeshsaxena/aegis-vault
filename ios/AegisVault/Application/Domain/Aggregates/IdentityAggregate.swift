import Foundation
import SecureVaultKit

struct IdentityAggregate: VaultObjectAggregate {
    let title: String
    let identityType: IdentityDocumentType
    let fullName: String
    let documentNumber: String
    let issueDate: Date?
    let expiryDate: Date?
    let notes: String
    let tags: [String]

    var objectType: VaultObjectType { .identity }

    init(data: IdentityEditorViewData) {
        self.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.identityType = data.identityType
        self.fullName = data.fullName
        self.documentNumber = data.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.issueDate = data.issueDate
        self.expiryDate = data.expiryDate
        self.notes = data.notes
        self.tags = data.tags
    }

    func validateInvariants() throws {
        guard !title.isEmpty else {
            throw ValidationError.missingTitle
        }
        guard !identityType.requiresDocumentNumber || !documentNumber.isEmpty else {
            throw ValidationError.missingRequiredField("documentNumber")
        }
    }

    func toVaultObjectDraft() throws -> VaultObjectDraft {
        try validateInvariants()
        return VaultObjectDraft(
            type: objectType,
            metadata: VaultMetadata(
                title: title,
                category: identityType.rawValue,
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
        metadata.category = identityType.rawValue
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
            "identityType": .text(identityType.rawValue),
            "fullName": .text(fullName),
            "documentNumber": .secureText(documentNumber)
        ]
        if let issueDate {
            fields["issueDate"] = .date(issueDate)
        }
        if let expiryDate {
            fields["expiryDate"] = .date(expiryDate)
        }
        return fields
    }
}
