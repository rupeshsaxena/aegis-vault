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

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveAppRouteUseCase: resolveAppRouteUseCase)
    }
}
