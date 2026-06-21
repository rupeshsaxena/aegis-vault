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
        "image/jpeg",
        "image/png",
        "application/pdf"
    ]

    private static let supportedExtensions: Set<String> = [
        "jpeg",
        "jpg",
        "pdf",
        "png"
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
    private let thumbnailGeneratorOverride: (any ThumbnailGenerator)?
    private let previewGeneratorOverride: (any PreviewGenerator)?

    init(
        workspaceFactory: @escaping @Sendable () throws -> TemporaryWorkspace = { try TemporaryWorkspace() },
        validator: DocumentValidator = DocumentValidator(),
        thumbnailGenerator: (any ThumbnailGenerator)? = nil,
        previewGenerator: (any PreviewGenerator)? = nil
    ) {
        self.workspaceFactory = workspaceFactory
        self.validator = validator
        self.thumbnailGeneratorOverride = thumbnailGenerator
        self.previewGeneratorOverride = previewGenerator
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
        var attachment = try await writeOriginalAttachment(
            for: stagedDocument,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        let thumbnailAttachment = try await generateThumbnailAttachment(
            for: stagedDocument,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        let previewAttachment = try await generatePreviewAttachment(
            for: stagedDocument,
            session: session,
            configuration: configuration,
            workspace: workspace
        )
        attachment.thumbnailBlobId = thumbnailAttachment?.blobId
        attachment.previewBlobId = previewAttachment?.blobId
        let attachments = [attachment, thumbnailAttachment, previewAttachment].compactMap { $0 }
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

    private func generateThumbnailAttachment(
        for document: StagedDocument,
        session: VaultSession,
        configuration: VaultKitConfiguration,
        workspace: TemporaryWorkspace
    ) async throws -> VaultAttachment? {
        do {
            let asset = try await thumbnailGenerator(for: document)
                .generateThumbnail(for: document, in: workspace)
            return try await writeGeneratedAttachment(
                asset,
                session: session,
                configuration: configuration,
                workspace: workspace
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func generatePreviewAttachment(
        for document: StagedDocument,
        session: VaultSession,
        configuration: VaultKitConfiguration,
        workspace: TemporaryWorkspace
    ) async throws -> VaultAttachment? {
        do {
            let asset = try await previewGenerator(for: document)
                .generatePreview(for: document, in: workspace)
            return try await writeGeneratedAttachment(
                asset,
                session: session,
                configuration: configuration,
                workspace: workspace
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
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
                "originalSizeBytes": .number(Double(importedMetadata.byteCount)),
                "importedAt": .date(importedMetadata.importedAt)
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
        if let thumbnailGeneratorOverride {
            return thumbnailGeneratorOverride
        }
        if document.metadata.contentType.lowercased().hasPrefix("image/") {
            return ImageThumbnailGenerator()
        }
        if document.metadata.contentType.lowercased() == "application/pdf" {
            return PDFThumbnailGenerator()
        }
        return GenericDocumentThumbnailGenerator()
    }

    private func previewGenerator(for document: StagedDocument) -> any PreviewGenerator {
        if let previewGeneratorOverride {
            return previewGeneratorOverride
        }
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
