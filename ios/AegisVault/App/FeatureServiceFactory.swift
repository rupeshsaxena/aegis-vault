import Foundation
import SecureVaultKit

@MainActor
final class FeatureServiceFactory {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func makeSecureNoteService() -> any SecureNoteApplicationServicing {
        SecureNoteApplicationService(
            createUseCase: CreateSecureNoteUseCase(vaultEngine: vaultEngine),
            updateUseCase: UpdateSecureNoteUseCase(vaultEngine: vaultEngine),
            detailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            moveToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            restoreUseCase: RestoreFromTrashUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeIdentityService() -> any IdentityApplicationServicing {
        IdentityApplicationService(
            createUseCase: CreateIdentityUseCase(vaultEngine: vaultEngine),
            updateUseCase: UpdateIdentityUseCase(vaultEngine: vaultEngine),
            detailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            moveToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            restoreUseCase: RestoreFromTrashUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeCardService() -> any CardApplicationServicing {
        CardApplicationService(
            createUseCase: CreateCardUseCase(vaultEngine: vaultEngine),
            updateUseCase: UpdateCardUseCase(vaultEngine: vaultEngine),
            detailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            moveToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            restoreUseCase: RestoreFromTrashUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeDocumentService() -> any DocumentApplicationServicing {
        DocumentApplicationService(
            importUseCase: ImportDocumentUseCase(vaultEngine: vaultEngine),
            detailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            thumbnailUseCase: LoadThumbnailUseCase(vaultEngine: vaultEngine),
            moveToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            restoreUseCase: RestoreFromTrashUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeTrashService() -> any TrashApplicationServicing {
        TrashApplicationService(
            listUseCase: ListTrashObjectsUseCase(vaultEngine: vaultEngine),
            restoreUseCase: RestoreFromTrashUseCase(vaultEngine: vaultEngine),
            purgeUseCase: PurgeTrashUseCase(vaultEngine: vaultEngine),
            permanentlyDeleteUseCase: PermanentlyDeleteObjectUseCase(vaultEngine: vaultEngine)
        )
    }
}
