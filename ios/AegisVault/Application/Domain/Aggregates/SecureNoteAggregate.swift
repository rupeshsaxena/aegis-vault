import Foundation
import SecureVaultKit

struct SecureNoteAggregate: VaultObjectAggregate {
    let title: String
    let content: String
    let tags: [String]

    var objectType: VaultObjectType { .secureNote }

    init(data: SecureNoteEditorViewData) {
        self.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = data.content
        self.tags = data.tags
    }

    func validateInvariants() throws {
        guard !title.isEmpty else {
            throw ValidationError.missingTitle
        }
    }

    func toVaultObjectDraft() throws -> VaultObjectDraft {
        try validateInvariants()
        return VaultObjectDraft(
            type: objectType,
            metadata: VaultMetadata(title: title, tags: tags),
            payload: VaultPayload(notes: content)
        )
    }

    func toVaultObjectUpdate(existing: VaultObjectDetail) throws -> VaultObjectUpdate {
        try validateInvariants()
        guard existing.type == objectType else {
            throw ValidationError.unsupportedType(existing.type.rawValue)
        }
        var metadata = existing.metadata
        metadata.title = title
        metadata.tags = tags
        metadata.updatedAt = Date()
        var payload = existing.payload
        payload.notes = content
        return VaultObjectUpdate(
            objectId: existing.id,
            metadata: metadata,
            payload: payload
        )
    }
}
