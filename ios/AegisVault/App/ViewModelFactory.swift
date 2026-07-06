import Foundation
import SecureVaultKit

@MainActor
final class ViewModelFactory {
    private let vaultEngine: any VaultEngine
    private let featureServiceFactory: FeatureServiceFactory

    init(
        vaultEngine: any VaultEngine,
        featureServiceFactory: FeatureServiceFactory
    ) {
        self.vaultEngine = vaultEngine
        self.featureServiceFactory = featureServiceFactory
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            createVaultUseCase: CreateVaultUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeUnlockViewModel() -> UnlockViewModel {
        UnlockViewModel(
            unlockVaultUseCase: UnlockVaultUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: ListVaultObjectsUseCase(vaultEngine: vaultEngine),
            searchVaultUseCase: SearchVaultUseCase(vaultEngine: vaultEngine),
            lockVaultUseCase: LockVaultUseCase(vaultEngine: vaultEngine),
            loadThumbnailUseCase: LoadThumbnailUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            moveObjectToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            loadThumbnailUseCase: LoadThumbnailUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeIdentityEditorViewModel() -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            identityService: featureServiceFactory.makeIdentityService()
        )
    }

    func makeSecureNoteEditorViewModel() -> SecureNoteEditorViewModel {
        SecureNoteEditorViewModel(
            secureNoteService: featureServiceFactory.makeSecureNoteService()
        )
    }

    func makeCardEditorViewModel() -> CardEditorViewModel {
        CardEditorViewModel(
            cardService: featureServiceFactory.makeCardService()
        )
    }

    func makeDocumentImportViewModel() -> DocumentImportViewModel {
        DocumentImportViewModel(
            documentService: featureServiceFactory.makeDocumentService()
        )
    }

    func makeTrashViewModel() -> TrashViewModel {
        TrashViewModel(
            trashService: featureServiceFactory.makeTrashService()
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            getSecurityStatusUseCase: GetSecurityStatusUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeSecurityCenterViewModel() -> SecurityCenterViewModel {
        SecurityCenterViewModel(
            getSecurityStatusUseCase: GetSecurityStatusUseCase(vaultEngine: vaultEngine),
            updateAutoLockPolicyUseCase: UpdateAutoLockPolicyUseCase(vaultEngine: vaultEngine),
            lockVaultUseCase: LockVaultUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeRecoverySettingsViewModel() -> RecoverySettingsViewModel {
        RecoverySettingsViewModel(
            getRecoveryStatusUseCase: GetRecoveryStatusUseCase(vaultEngine: vaultEngine),
            exportRecoveryPackageUseCase: ExportRecoveryPackageUseCase(vaultEngine: vaultEngine)
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(
            resolveAppRouteUseCase: ResolveAppRouteUseCase(vaultEngine: vaultEngine)
        )
    }
}
