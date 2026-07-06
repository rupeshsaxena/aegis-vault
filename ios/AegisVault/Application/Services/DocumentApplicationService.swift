import Foundation
import SecureVaultKit

protocol DocumentApplicationServicing: Sendable {
    func inspectDocument(fileURL: URL) async throws -> DocumentImportFileInfo
    func importDocument(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID
    func loadDocument(id: VaultObjectID) async throws -> VaultObjectDetail
    func loadThumbnail(objectId: VaultObjectID) async throws -> VaultThumbnail
    func moveToTrash(id: VaultObjectID) async throws
    func restore(id: VaultObjectID) async throws
}

struct DocumentApplicationService: DocumentApplicationServicing {
    private let importUseCase: any ImportDocumentUsing
    private let detailUseCase: any GetObjectDetailUsing
    private let thumbnailUseCase: any LoadThumbnailUsing
    private let moveToTrashUseCase: any MoveObjectToTrashUsing
    private let restoreUseCase: any RestoreFromTrashUsing

    init(
        importUseCase: any ImportDocumentUsing,
        detailUseCase: any GetObjectDetailUsing,
        thumbnailUseCase: any LoadThumbnailUsing,
        moveToTrashUseCase: any MoveObjectToTrashUsing,
        restoreUseCase: any RestoreFromTrashUsing
    ) {
        self.importUseCase = importUseCase
        self.detailUseCase = detailUseCase
        self.thumbnailUseCase = thumbnailUseCase
        self.moveToTrashUseCase = moveToTrashUseCase
        self.restoreUseCase = restoreUseCase
    }

    func inspectDocument(fileURL: URL) async throws -> DocumentImportFileInfo {
        try await importUseCase.inspect(fileURL: fileURL)
    }

    func importDocument(fileURL: URL, vaultID: VaultID) async throws -> VaultObjectID {
        try await importUseCase.execute(fileURL: fileURL, vaultID: vaultID)
    }

    func loadDocument(id: VaultObjectID) async throws -> VaultObjectDetail {
        try await detailUseCase.execute(id: id)
    }

    func loadThumbnail(objectId: VaultObjectID) async throws -> VaultThumbnail {
        try await thumbnailUseCase.execute(objectId: objectId)
    }

    func moveToTrash(id: VaultObjectID) async throws {
        try await moveToTrashUseCase.execute(id: id)
    }

    func restore(id: VaultObjectID) async throws {
        try await restoreUseCase.execute(id: id)
    }
}
