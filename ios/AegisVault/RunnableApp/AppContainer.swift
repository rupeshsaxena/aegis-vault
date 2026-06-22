import SecureVaultKit

// MARK: - Use Case Protocols

protocol CreateVaultUsing: Sendable {
    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID
}

protocol ListVaultObjectsUsing: Sendable {
    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
}

// MARK: - Use Case Implementations

struct CreateVaultUseCase: CreateVaultUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(name: String, deviceID: DeviceID, unlockMethod: UnlockMethod) async throws -> VaultID {
        try await vaultEngine.createVault(
            config: VaultCreationConfig(name: name, deviceID: deviceID, unlockMethod: unlockMethod)
        )
    }
}

struct ListVaultObjectsUseCase: ListVaultObjectsUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        try await vaultEngine.listObjects(filter: filter)
    }
}

// MARK: - Container

@MainActor
final class AppContainer {
    let vaultEngine: any VaultEngine
    let resolveRootRouteUseCase: any ResolveRootRouteUsing
    let createVaultUseCase: any CreateVaultUsing
    let listVaultObjectsUseCase: any ListVaultObjectsUsing

    init(vaultEngine: any VaultEngine = VaultEngineFactory.makeSimulatorEngine()) {
        self.vaultEngine = vaultEngine
        self.resolveRootRouteUseCase = ResolveRootRouteUseCase(vaultEngine: vaultEngine)
        self.createVaultUseCase = CreateVaultUseCase(vaultEngine: vaultEngine)
        self.listVaultObjectsUseCase = ListVaultObjectsUseCase(vaultEngine: vaultEngine)
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(resolveRootRouteUseCase: resolveRootRouteUseCase)
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createVaultUseCase: createVaultUseCase)
    }

    func makeVaultHomeViewModel() -> VaultHomeViewModel {
        VaultHomeViewModel(listVaultObjectsUseCase: listVaultObjectsUseCase)
    }
}
