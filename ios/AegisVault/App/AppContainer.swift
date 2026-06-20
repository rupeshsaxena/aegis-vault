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
            lockVaultUseCase: lockVaultUseCase
        )
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        ObjectDetailViewModel(
            getObjectDetailUseCase: getObjectDetailUseCase,
            moveObjectToTrashUseCase: moveObjectToTrashUseCase
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveAppRouteUseCase: resolveAppRouteUseCase)
    }
}
