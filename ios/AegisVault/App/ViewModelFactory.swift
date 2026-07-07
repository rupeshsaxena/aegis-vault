import Foundation
import SecureVaultKit

@MainActor
final class ViewModelFactory {
    private let vaultEngine: any VaultEngine
    private let featureServiceFactory: FeatureServiceFactory
    private let errorMapper: any ErrorMapper

    init(
        vaultEngine: any VaultEngine,
        featureServiceFactory: FeatureServiceFactory,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.vaultEngine = vaultEngine
        self.featureServiceFactory = featureServiceFactory
        self.errorMapper = errorMapper
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            createVaultUseCase: CreateVaultUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeUnlockViewModel() -> UnlockViewModel {
        UnlockViewModel(
            unlockVaultUseCase: UnlockVaultUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: ListVaultObjectsUseCase(vaultEngine: vaultEngine),
            searchVaultUseCase: SearchVaultUseCase(vaultEngine: vaultEngine),
            lockVaultUseCase: LockVaultUseCase(vaultEngine: vaultEngine),
            loadThumbnailUseCase: LoadThumbnailUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: GetObjectDetailUseCase(vaultEngine: vaultEngine),
            moveObjectToTrashUseCase: MoveObjectToTrashUseCase(vaultEngine: vaultEngine),
            loadThumbnailUseCase: LoadThumbnailUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeIdentityEditorViewModel() -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            identityService: featureServiceFactory.makeIdentityService(),
            errorMapper: errorMapper
        )
    }

    func makeSecureNoteEditorViewModel() -> SecureNoteEditorViewModel {
        SecureNoteEditorViewModel(
            secureNoteService: featureServiceFactory.makeSecureNoteService(),
            errorMapper: errorMapper
        )
    }

    func makeCardEditorViewModel() -> CardEditorViewModel {
        CardEditorViewModel(
            cardService: featureServiceFactory.makeCardService(),
            errorMapper: errorMapper
        )
    }

    func makeDocumentImportViewModel() -> DocumentImportViewModel {
        DocumentImportViewModel(
            documentService: featureServiceFactory.makeDocumentService(),
            errorMapper: errorMapper
        )
    }

    func makeTrashViewModel() -> TrashViewModel {
        TrashViewModel(
            trashService: featureServiceFactory.makeTrashService(),
            errorMapper: errorMapper
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            getSecurityStatusUseCase: GetSecurityStatusUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeSecurityCenterViewModel() -> SecurityCenterViewModel {
        SecurityCenterViewModel(
            getSecurityStatusUseCase: GetSecurityStatusUseCase(vaultEngine: vaultEngine),
            updateAutoLockPolicyUseCase: UpdateAutoLockPolicyUseCase(vaultEngine: vaultEngine),
            lockVaultUseCase: LockVaultUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeRecoverySettingsViewModel() -> RecoverySettingsViewModel {
        RecoverySettingsViewModel(
            getRecoveryStatusUseCase: GetRecoveryStatusUseCase(vaultEngine: vaultEngine),
            exportRecoveryPackageUseCase: ExportRecoveryPackageUseCase(vaultEngine: vaultEngine),
            errorMapper: errorMapper
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(
            resolveAppRouteUseCase: ResolveAppRouteUseCase(vaultEngine: vaultEngine)
        )
    }
}
