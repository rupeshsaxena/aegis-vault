import Foundation

internal protocol DocumentImportService: Sendable {
    func importDocument(
        _ input: DocumentImportInput,
        into vaultId: VaultID,
        session: VaultSession,
        configuration: VaultKitConfiguration
    ) async throws -> DocumentImportResult
}

internal final class TemporaryWorkspace: @unchecked Sendable {
    let rootURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.temporaryDirectory
            .appendingPathComponent("SecureVaultKitImport-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    func copy(_ input: DocumentImportInput) throws -> StagedDocument {
        let destinationURL = rootURL.appendingPathComponent(input.fileName)
        let byteCount: Int
        let stagedData: Data
        if let data = input.data {
            try data.write(to: destinationURL, options: .atomic)
            byteCount = data.count
            stagedData = data
        } else if let fileURL = input.fileURL {
            let copiedSize = try StreamingFileCopy.copy(
                from: fileURL,
                to: destinationURL,
                chunkSize: BlobEncryptionPolicy.default.chunkSize,
                fileManager: fileManager
            )
            byteCount = Int(copiedSize)
            stagedData = Data()
        } else {
            throw VaultError.invalidInput("Document import requires file data or a file URL.")
        }
        let metadata = ImportedDocumentMetadata(
            fileName: input.fileName,
            contentType: input.contentType,
            byteCount: byteCount,
            fileExtension: destinationURL.pathExtension.lowercased()
        )
        return StagedDocument(url: destinationURL, data: stagedData, metadata: metadata)
    }

    func writeGeneratedFile(fileName: String, data: Data) throws -> URL {
        let destinationURL = rootURL.appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    func cleanup() {
        try? fileManager.removeItem(at: rootURL)
    }
}

internal struct StagedDocument: Sendable {
    var url: URL
    var data: Data
    var metadata: ImportedDocumentMetadata
}

internal struct DocumentValidator: Sendable {
    private static let supportedContentTypes: Set<String> = [
        "image/heic",
        "image/jpeg",
        "image/png",
        "application/pdf",
        "application/msword",
        "application/rtf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain"
    ]

    private static let supportedExtensions: Set<String> = [
        "doc",
        "docx",
        "heic",
        "jpeg",
        "jpg",
        "pdf",
        "png",
        "rtf",
        "txt"
    ]

    func validate(_ input: DocumentImportInput) throws {
        guard !input.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VaultError.invalidInput("Document file name must not be empty.")
        }
        guard Self.supportedContentTypes.contains(input.contentType.lowercased()) else {
            throw VaultError.unsupportedOperation("Unsupported document content type.")
        }
        let fileExtension = URL(fileURLWithPath: input.fileName).pathExtension.lowercased()
        guard Self.supportedExtensions.contains(fileExtension) else {
            throw VaultError.unsupportedOperation("Unsupported document file type.")
        }
        if let fileURL = input.fileURL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw VaultError.invalidInput("Document file does not exist.")
            }
        }
        guard try Self.byteCount(of: input) > 0 else {
            throw VaultError.invalidInput("Document file must not be empty.")
        }
    }

    private static func byteCount(of input: DocumentImportInput) throws -> Int64 {
        if let data = input.data {
            return Int64(data.count)
        }
        guard let fileURL = input.fileURL else {
            throw VaultError.invalidInput("Document import requires file data or a file URL.")
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? NSNumber else {
                throw VaultError.invalidInput("Document file size is unavailable.")
            }
            return size.int64Value
        } catch {
            if let vaultError = error as? VaultError {
                throw vaultError
            }
            throw VaultError.invalidInput("Document file does not exist.")
        }
    }
}

internal final class DefaultDocumentImportService: DocumentImportService, @unchecked Sendable {
    private let workspaceFactory: @Sendable () throws -> TemporaryWorkspace
    private let validator: DocumentValidator

    init(
        workspaceFactory: @escaping @Sendable () throws -> TemporaryWorkspace = { try TemporaryWorkspace() },
        validator: DocumentValidator = DocumentValidator()
    ) {
        self.workspaceFactory = workspaceFactory
        self.validator = validator
    }

    func importDocument(
        _ input: DocumentImportInput,
        into vaultId: VaultID,
        session: VaultSession,
        configuration: VaultKitConfiguration
    ) async throws -> DocumentImportResult {
        try validator.validate(input)
        let workspace = try workspaceFactory()
        defer { workspace.cleanup() }

        let stagedDocument = try workspace.copy(input)
        let attachment = try await writeOriginalAttachment(
            for: stagedDocument,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        let thumbnailAsset = try await thumbnailGenerator(for: stagedDocument)
            .generateThumbnail(for: stagedDocument, in: workspace)
        let thumbnailAttachment = try await writeGeneratedAttachment(
            thumbnailAsset,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        let previewAsset = try await previewGenerator(for: stagedDocument)
            .generatePreview(for: stagedDocument, in: workspace)
        let previewAttachment = try await writeGeneratedAttachment(
            previewAsset,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        let attachments = [attachment, thumbnailAttachment, previewAttachment]
        let objectId = try await createDocumentObject(
            attachments: attachments,
            metadata: stagedDocument.metadata,
            vaultId: vaultId,
            session: session,
            configuration: configuration
        )
        for attachment in attachments {
            try await configuration.eventEngine.append(
                .attachmentAdded(vaultId: vaultId, objectId: objectId, blobId: attachment.id)
            )
        }

        return DocumentImportResult(
            objectId: objectId,
            attachment: attachment,
            thumbnailAttachment: thumbnailAttachment,
            previewAttachment: previewAttachment,
            metadata: stagedDocument.metadata
        )
    }

    private func writeOriginalAttachment(
        for document: StagedDocument,
        session: VaultSession,
        configuration: VaultKitConfiguration,
        workspace: TemporaryWorkspace
    ) async throws -> VaultAttachment {
        let blobResult = try await writeEncryptedBlob(
            from: document.url,
            contentType: document.metadata.contentType,
            role: .original,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        return VaultAttachment(
            id: blobResult.id,
            role: .primary,
            fileName: document.metadata.fileName,
            contentType: blobResult.contentType,
            byteCount: blobResult.byteCount
        )
    }

    private func writeGeneratedAttachment(
        _ asset: GeneratedBlobAsset,
        session: VaultSession,
        configuration: VaultKitConfiguration,
        workspace: TemporaryWorkspace
    ) async throws -> VaultAttachment {
        let blobResult = try await writeEncryptedBlob(
            from: asset.fileURL,
            contentType: asset.contentType,
            role: asset.role.blobRole,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        return VaultAttachment(
            id: blobResult.id,
            role: asset.role,
            fileName: asset.fileName,
            contentType: blobResult.contentType,
            byteCount: blobResult.byteCount
        )
    }

    private func writeEncryptedBlob(
        from inputURL: URL,
        contentType: String,
        role: BlobRole,
        session: VaultSession,
        configuration: VaultKitConfiguration,
        workspace: TemporaryWorkspace
    ) async throws -> BlobWriteResult {
        let blobKey = try await configuration.cryptoEngine.generateKey()
        let encryptedURL = workspace.rootURL
            .appendingPathComponent("encrypted-\(UUID().uuidString).blob")
        let encryptionResult = try await configuration.blobEncryptionEngine.encryptBlob(
            inputURL: inputURL,
            outputURL: encryptedURL,
            using: blobKey
        )
        return try await configuration.blobStore.writeEncryptedBlob(
            from: encryptedURL,
            result: encryptionResult,
            contentType: contentType,
            role: role
        )
    }

    private func createDocumentObject(
        attachments: [VaultAttachment],
        metadata importedMetadata: ImportedDocumentMetadata,
        vaultId: VaultID,
        session: VaultSession,
        configuration: VaultKitConfiguration
    ) async throws -> VaultObjectID {
        let objectId = VaultObjectID()
        let now = importedMetadata.importedAt
        let itemKey = try await configuration.cryptoEngine.generateItemKey(for: objectId)
        let metadata = VaultMetadata(
            title: importedMetadata.fileName,
            subtitle: importedMetadata.contentType,
            tags: ["document"],
            createdAt: now,
            updatedAt: now
        )
        let payload = VaultPayload(
            fields: [
                "fileName": .text(importedMetadata.fileName),
                "contentType": .text(importedMetadata.contentType),
                "byteCount": .number(Double(importedMetadata.byteCount))
            ],
            attachments: attachments
        )
        let encryptedMetadata = try await configuration.cryptoEngine.encryptMetadata(metadata, using: itemKey)
        let encryptedPayload = try await configuration.cryptoEngine.encryptPayload(payload, using: itemKey)
        let wrappedItemKey = try await configuration.cryptoEngine.wrapItemKey(
            itemKey,
            usingVaultEncryptionKey: session.keyReferences.vaultEncryptionKeyReference
                ?? session.keyReferences.vaultKeyReference
                ?? "fake-missing-vault-encryption-key"
        )
        let record = VaultObjectRecord(
            id: objectId,
            vaultId: vaultId,
            type: .document,
            encryptedMetadata: encryptedMetadata,
            encryptedPayload: encryptedPayload,
            wrappedItemKey: wrappedItemKey,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        let summary = VaultObjectSummary(
            id: objectId,
            vaultId: vaultId,
            type: .document,
            title: metadata.title,
            subtitle: metadata.subtitle,
            tags: metadata.tags,
            updatedAt: metadata.updatedAt,
            version: 1
        )

        try await configuration.storageEngine.insertObject(record)
        try await configuration.eventEngine.append(.objectCreated(vaultId: vaultId, objectId: objectId))
        try await configuration.searchEngine.index(summary)

        return objectId
    }

    private func thumbnailGenerator(for document: StagedDocument) -> any ThumbnailGenerator {
        if document.metadata.contentType.lowercased().hasPrefix("image/") {
            return ImageThumbnailGenerator()
        }
        if document.metadata.contentType.lowercased() == "application/pdf" {
            return PDFThumbnailGenerator()
        }
        return GenericDocumentThumbnailGenerator()
    }

    private func previewGenerator(for document: StagedDocument) -> any PreviewGenerator {
        if document.metadata.contentType.lowercased().hasPrefix("image/") {
            return ImagePreviewGenerator()
        }
        if document.metadata.contentType.lowercased() == "application/pdf" {
            return PDFPreviewGenerator()
        }
        return GenericDocumentPreviewGenerator()
    }
}

private extension AttachmentRole {
    var blobRole: BlobRole {
        switch self {
        case .primary:
            .original
        case .thumbnail:
            .thumbnail
        case .preview:
            .preview
        case .supporting:
            .supporting
        }
    }
}
