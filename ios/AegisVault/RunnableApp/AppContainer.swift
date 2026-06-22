import SecureVaultKit

@MainActor
final class AppContainer {
    let vaultEngine: any VaultEngine
    let resolveRootRouteUseCase: any ResolveRootRouteUsing

    init(vaultEngine: any VaultEngine = VaultEngineFactory.makeBootstrapEngine()) {
        self.vaultEngine = vaultEngine
        self.resolveRootRouteUseCase = ResolveRootRouteUseCase(vaultEngine: vaultEngine)
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: resolveRootRouteUseCase)
    }
}
