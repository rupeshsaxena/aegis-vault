import Foundation
import SecureVaultKit

@MainActor
final class AppContainer {
    let environment: AppEnvironment
    let dependencyFactory: AppDependencyFactory
    let serviceFactory: FeatureServiceFactory
    let viewModelFactory: ViewModelFactory

    private let vaultEngine: any VaultEngine
    private let navigationCoordinator: AppNavigationCoordinator

    init(
        environment: AppEnvironment = .current(),
        dependencyFactory: AppDependencyFactory? = nil,
        engineFactory: (@Sendable () throws -> any VaultEngine)? = nil
    ) throws {
        self.environment = environment
        let dependencyFactory = dependencyFactory ?? AppDependencyFactory(environment: environment)
        self.dependencyFactory = dependencyFactory

        let engine = try engineFactory?() ?? dependencyFactory.makeVaultEngine()
        self.vaultEngine = engine
        self.navigationCoordinator = AppNavigationCoordinator()

        let serviceFactory = FeatureServiceFactory(vaultEngine: engine)
        self.serviceFactory = serviceFactory
        self.viewModelFactory = ViewModelFactory(
            vaultEngine: engine,
            featureServiceFactory: serviceFactory,
            navigationCoordinator: navigationCoordinator
        )
    }

    static func makeDefault() throws -> AppContainer {
        try AppContainer(environment: .current())
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        viewModelFactory.makeOnboardingViewModel()
    }

    func makeUnlockViewModel() -> UnlockViewModel {
        viewModelFactory.makeUnlockViewModel()
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        viewModelFactory.makeVaultHomeViewModel()
    }

    func makeObjectDetailViewModel() -> ObjectDetailViewModel {
        viewModelFactory.makeObjectDetailViewModel()
    }

    func makeIdentityEditorViewModel() -> IdentityEditorViewModel {
        viewModelFactory.makeIdentityEditorViewModel()
    }

    func makeSecureNoteEditorViewModel() -> SecureNoteEditorViewModel {
        viewModelFactory.makeSecureNoteEditorViewModel()
    }

    func makeCardEditorViewModel() -> CardEditorViewModel {
        viewModelFactory.makeCardEditorViewModel()
    }

    func makeDocumentImportViewModel() -> DocumentImportViewModel {
        viewModelFactory.makeDocumentImportViewModel()
    }

    func makeTrashViewModel() -> TrashViewModel {
        viewModelFactory.makeTrashViewModel()
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        viewModelFactory.makeSettingsViewModel()
    }

    func makeSecurityCenterViewModel() -> SecurityCenterViewModel {
        viewModelFactory.makeSecurityCenterViewModel()
    }

    func makeRecoverySettingsViewModel() -> RecoverySettingsViewModel {
        viewModelFactory.makeRecoverySettingsViewModel()
    }

    func makeRootViewModel() -> RootViewModel {
        viewModelFactory.makeRootViewModel()
    }

    func makeAppLifecycleCoordinator() -> AppLifecycleCoordinator {
        AppLifecycleCoordinator(
            getSecurityStatusUseCase: GetSecurityStatusUseCase(vaultEngine: vaultEngine),
            lockVaultUseCase: LockVaultUseCase(vaultEngine: vaultEngine),
            navigationCoordinator: navigationCoordinator
        )
    }
}
