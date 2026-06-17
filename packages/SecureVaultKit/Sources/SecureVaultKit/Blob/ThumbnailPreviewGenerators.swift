import Foundation

internal protocol ThumbnailGenerator: Sendable {
    func generateThumbnail(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset
}

internal protocol PreviewGenerator: Sendable {
    func generatePreview(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset
}

internal struct GeneratedBlobAsset: Equatable, Sendable {
    var fileURL: URL
    var fileName: String
    var contentType: String
    var role: AttachmentRole
}

internal struct ImageThumbnailGenerator: ThumbnailGenerator {
    func generateThumbnail(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "thumbnail",
            fileExtension: "png",
            contentType: "image/png",
            role: .thumbnail,
            marker: "image-thumbnail"
        )
    }
}

internal struct PDFThumbnailGenerator: ThumbnailGenerator {
    func generateThumbnail(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "thumbnail",
            fileExtension: "png",
            contentType: "image/png",
            role: .thumbnail,
            marker: "pdf-thumbnail"
        )
    }
}

internal struct GenericDocumentThumbnailGenerator: ThumbnailGenerator {
    func generateThumbnail(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "thumbnail",
            fileExtension: "png",
            contentType: "image/png",
            role: .thumbnail,
            marker: "generic-document-thumbnail"
        )
    }
}

internal struct ImagePreviewGenerator: PreviewGenerator {
    func generatePreview(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "preview",
            fileExtension: document.metadata.fileExtension.isEmpty ? "img" : document.metadata.fileExtension,
            contentType: document.metadata.contentType,
            role: .preview,
            marker: "image-preview"
        )
    }
}

internal struct PDFPreviewGenerator: PreviewGenerator {
    func generatePreview(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "preview",
            fileExtension: "pdf",
            contentType: "application/pdf",
            role: .preview,
            marker: "pdf-preview"
        )
    }
}

internal struct GenericDocumentPreviewGenerator: PreviewGenerator {
    func generatePreview(
        for document: StagedDocument,
        in workspace: TemporaryWorkspace
    ) async throws -> GeneratedBlobAsset {
        try await generatedAsset(
            for: document,
            in: workspace,
            suffix: "preview",
            fileExtension: "txt",
            contentType: "text/plain",
            role: .preview,
            marker: "generic-document-preview"
        )
    }
}

private func generatedAsset(
    for document: StagedDocument,
    in workspace: TemporaryWorkspace,
    suffix: String,
    fileExtension: String,
    contentType: String,
    role: AttachmentRole,
    marker: String
) async throws -> GeneratedBlobAsset {
    try Task.checkCancellation()
    let baseName = document.metadata.fileNameBase
    let fileName = "\(baseName)-\(suffix).\(fileExtension)"
    let data = Data(
        [
            "SecureVaultKit generated asset",
            "kind=\(marker)",
            "source=\(document.metadata.fileName)",
            "bytes=\(document.metadata.byteCount)"
        ].joined(separator: "\n").utf8
    )
    let fileURL = try workspace.writeGeneratedFile(fileName: fileName, data: data)
    return GeneratedBlobAsset(
        fileURL: fileURL,
        fileName: fileName,
        contentType: contentType,
        role: role
    )
}

private extension ImportedDocumentMetadata {
    var fileNameBase: String {
        let url = URL(fileURLWithPath: fileName)
        let baseName = url.deletingPathExtension().lastPathComponent
        return baseName.isEmpty ? "document" : baseName
    }
}
