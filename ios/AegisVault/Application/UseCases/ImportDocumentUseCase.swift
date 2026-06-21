import Foundation
import SecureVaultKit

protocol ImportDocumentUsing: Sendable {
    func inspect(fileURL: URL) async throws -> DocumentImportFileInfo
    func execute(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID
}

struct ImportDocumentUseCase: ImportDocumentUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func inspect(fileURL: URL) async throws -> DocumentImportFileInfo {
        await Task.yield()
        return try withSecurityScopedAccess(to: fileURL) {
            let fileName = fileURL.lastPathComponent
            guard let contentType = Self.contentType(for: fileURL.pathExtension) else {
                throw VaultError.unsupportedOperation("Unsupported document file type.")
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
                throw VaultError.invalidInput("Document file must not be empty.")
            }
            return DocumentImportFileInfo(
                fileName: fileName,
                contentType: contentType,
                originalSizeBytes: size.int64Value
            )
        }
    }

    func execute(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        let fileInfo = try await inspect(fileURL: fileURL)
        return try await withSecurityScopedAccess(to: fileURL) {
            let result = try await vaultEngine.importDocument(
                DocumentImportInput(
                    fileURL: fileURL,
                    contentType: fileInfo.contentType,
                    fileName: fileInfo.fileName
                ),
                into: vaultID
            )
            return result.objectId
        }
    }

    private func withSecurityScopedAccess<T: Sendable>(
        to fileURL: URL,
        operation: () async throws -> T
    ) async throws -> T {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }

    private func withSecurityScopedAccess<T>(
        to fileURL: URL,
        operation: () throws -> T
    ) throws -> T {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    private static func contentType(for fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: nil
        }
    }
}
