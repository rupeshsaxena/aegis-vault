import Foundation
import SecureVaultKit

struct DocumentAggregate: VaultObjectAggregate {
    let fileName: String
    let contentType: String
    let originalSizeBytes: Int64
    let hasAttachmentReference: Bool

    var objectType: VaultObjectType { .document }

    init(
        fileInfo: DocumentImportFileInfo,
        hasAttachmentReference: Bool = true
    ) {
        self.fileName = fileInfo.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contentType = fileInfo.contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        self.originalSizeBytes = fileInfo.originalSizeBytes
        self.hasAttachmentReference = hasAttachmentReference
    }

    func validateInvariants() throws {
        guard !fileName.isEmpty else {
            throw ValidationError.missingRequiredField("filename")
        }
        guard !contentType.isEmpty else {
            throw ValidationError.missingRequiredField("contentType")
        }
        guard hasAttachmentReference else {
            throw ValidationError.invalidState("Document requires an attachment reference.")
        }
    }

    func toVaultObjectDraft() throws -> VaultObjectDraft {
        try validateInvariants()
        return VaultObjectDraft(
            type: objectType,
            metadata: VaultMetadata(title: fileName, category: contentType),
            payload: VaultPayload(
                fields: [
                    "filename": .text(fileName),
                    "contentType": .text(contentType),
                    "originalSizeBytes": .number(Double(originalSizeBytes))
                ]
            )
        )
    }
}
