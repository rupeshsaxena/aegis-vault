import SecureVaultKit

protocol ResolveRootRouteUsing: Sendable {
    func execute() async throws -> RootRoute
}

struct ResolveRootRouteUseCase: ResolveRootRouteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> RootRoute {
        switch try await vaultEngine.runtimeStatus() {
        case .missing:
            return .onboarding
        case .locked:
            return .unlock
        case .unlocked:
            return .vaultHome
        }
    }
}

