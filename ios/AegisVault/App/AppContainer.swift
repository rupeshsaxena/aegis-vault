import SecureVaultKit

@MainActor
final class AppContainer {
    private let vaultEngine: any VaultEngine
    let createVaultUseCase: any CreateVaultUsing
    let unlockVaultUseCase: any UnlockVaultUsing
    let lockVaultUseCase: any LockVaultUsing
    let searchVaultUseCase: any SearchVaultUsing
    let listVaultObjectsUseCase: any ListVaultObjectsUsing
    let getObjectDetailUseCase: any GetObjectDetailUsing
    let moveObjectToTrashUseCase: any MoveObjectToTrashUsing
    let createIdentityUseCase: any CreateIdentityUsing
    let updateIdentityUseCase: any UpdateIdentityUsing
    let createCardUseCase: any CreateCardUsing
    let updateCardUseCase: any UpdateCardUsing
    let importDocumentUseCase: any ImportDocumentUsing
    let loadThumbnailUseCase: any LoadThumbnailUsing
    let listTrashObjectsUseCase: any ListTrashObjectsUsing
    let restoreFromTrashUseCase: any RestoreFromTrashUsing
    let purgeTrashUseCase: any PurgeTrashUsing
    let permanentlyDeleteObjectUseCase: any PermanentlyDeleteObjectUsing
    let getSecurityStatusUseCase: any GetSecurityStatusUsing
    let updateAutoLockPolicyUseCase: any UpdateAutoLockPolicyUsing
    let listTrustedDevicesUseCase: any ListTrustedDevicesUsing
    let getRecoveryStatusUseCase: any GetRecoveryStatusUsing
    let exportRecoveryPackageUseCase: any ExportRecoveryPackageUsing
    let resolveAppRouteUseCase: any ResolveAppRouteUsing

    init(engineFactory: @Sendable () -> any VaultEngine) {
        let engine = engineFactory()
        self.vaultEngine = engine
        self.createVaultUseCase = CreateVaultUseCase(vaultEngine: engine)
        self.unlockVaultUseCase = UnlockVaultUseCase(vaultEngine: engine)
        self.lockVaultUseCase = LockVaultUseCase(vaultEngine: engine)
        self.searchVaultUseCase = SearchVaultUseCase(vaultEngine: engine)
        self.listVaultObjectsUseCase = ListVaultObjectsUseCase(vaultEngine: engine)
        self.getObjectDetailUseCase = GetObjectDetailUseCase(vaultEngine: engine)
        self.moveObjectToTrashUseCase = MoveObjectToTrashUseCase(vaultEngine: engine)
        self.createIdentityUseCase = CreateIdentityUseCase(vaultEngine: engine)
        self.updateIdentityUseCase = UpdateIdentityUseCase(vaultEngine: engine)
        self.createCardUseCase = CreateCardUseCase(vaultEngine: engine)
        self.updateCardUseCase = UpdateCardUseCase(vaultEngine: engine)
        self.importDocumentUseCase = ImportDocumentUseCase(vaultEngine: engine)
        self.loadThumbnailUseCase = LoadThumbnailUseCase(vaultEngine: engine)
        self.listTrashObjectsUseCase = ListTrashObjectsUseCase(vaultEngine: engine)
        self.restoreFromTrashUseCase = RestoreFromTrashUseCase(vaultEngine: engine)
        self.purgeTrashUseCase = PurgeTrashUseCase(vaultEngine: engine)
        self.permanentlyDeleteObjectUseCase = PermanentlyDeleteObjectUseCase(vaultEngine: engine)
        self.getSecurityStatusUseCase = GetSecurityStatusUseCase(vaultEngine: engine)
        self.updateAutoLockPolicyUseCase = UpdateAutoLockPolicyUseCase(vaultEngine: engine)
        self.listTrustedDevicesUseCase = ListTrustedDevicesUseCase(vaultEngine: engine)
        self.getRecoveryStatusUseCase = GetRecoveryStatusUseCase(vaultEngine: engine)
        self.exportRecoveryPackageUseCase = ExportRecoveryPackageUseCase(vaultEngine: engine)
        self.resolveAppRouteUseCase = ResolveAppRouteUseCase(vaultEngine: engine)
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createVaultUseCase: createVaultUseCase)
    }

    func makeUnlockViewModel() -> UnlockViewModel {
        UnlockViewModel(unlockVaultUseCase: unlockVaultUseCase)
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        VaultHomeViewModel(
            listVaultObjectsUseCase: listVaultObjectsUseCase,
            searchVaultUseCase: searchVaultUseCase,
            lockVaultUseCase: lockVaultUseCase,
            loadThumbnailUseCase: loadThumbnailUseCase
        )
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: getObjectDetailUseCase,
            moveObjectToTrashUseCase: moveObjectToTrashUseCase,
            loadThumbnailUseCase: loadThumbnailUseCase
        )
    }

    func makeIdentityEditorViewModel() -> IdentityEditorViewModel {
        IdentityEditorViewModel(
            createIdentityUseCase: createIdentityUseCase,
            updateIdentityUseCase: updateIdentityUseCase,
            getObjectDetailUseCase: getObjectDetailUseCase
        )
    }

    func makeCardEditorViewModel() -> CardEditorViewModel {
        CardEditorViewModel(
            createCardUseCase: createCardUseCase,
            updateCardUseCase: updateCardUseCase,
            getObjectDetailUseCase: getObjectDetailUseCase
        )
    }

    func makeDocumentImportViewModel() -> DocumentImportViewModel {
        DocumentImportViewModel(importDocumentUseCase: importDocumentUseCase)
    }

    func makeTrashViewModel() -> TrashViewModel {
        TrashViewModel(
            listTrashObjectsUseCase: listTrashObjectsUseCase,
            restoreFromTrashUseCase: restoreFromTrashUseCase,
            purgeTrashUseCase: purgeTrashUseCase,
            permanentlyDeleteObjectUseCase: permanentlyDeleteObjectUseCase
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(getSecurityStatusUseCase: getSecurityStatusUseCase)
    }

    func makeSecurityCenterViewModel() -> SecurityCenterViewModel {
        SecurityCenterViewModel(
            getSecurityStatusUseCase: getSecurityStatusUseCase,
            updateAutoLockPolicyUseCase: updateAutoLockPolicyUseCase,
            lockVaultUseCase: lockVaultUseCase
        )
    }

    func makeRecoverySettingsViewModel() -> RecoverySettingsViewModel {
        RecoverySettingsViewModel(
            getRecoveryStatusUseCase: getRecoveryStatusUseCase,
            exportRecoveryPackageUseCase: exportRecoveryPackageUseCase
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveAppRouteUseCase: resolveAppRouteUseCase)
    }
}
