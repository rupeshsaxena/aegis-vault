import SecureVaultKit

protocol ResolveAppRouteUsing: Sendable {
    func execute() async throws -> AppRoute
}

struct ResolveAppRouteUseCase: ResolveAppRouteUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> AppRoute {
        switch try await vaultEngine.runtimeStatus() {
        case .missing:
            return .onboarding
        case .locked(let vaultID):
            return .unlock(vaultID)
        case .unlocked(let vaultID):
            return .vaultHome(vaultID)
        }
    }
}
