import Combine
import Foundation
import SecureVaultKit

@MainActor
final class RootViewModel: ObservableObject {
    @Published var route: AppRoute?
    @Published private(set) var appState: AppState = .launching
    @Published private(set) var errorMessage: String?
    @Published private(set) var activeVaultID: VaultID?
    private let resolveAppRouteUseCase: any ResolveAppRouteUsing
    private let navigationCoordinator: AppNavigationCoordinator

    init(
        resolveAppRouteUseCase: any ResolveAppRouteUsing,
        navigationCoordinator: AppNavigationCoordinator? = nil
    ) {
        self.resolveAppRouteUseCase = resolveAppRouteUseCase
        self.navigationCoordinator = navigationCoordinator ?? AppNavigationCoordinator()
        bindNavigationCoordinator()
    }

    func resolveInitialRoute() async {
        guard route == nil else { return }
        do {
            let resolvedRoute = try await resolveAppRouteUseCase.execute()
            navigationCoordinator.setInitialRoute(resolvedRoute)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to open the vault."
        }
    }

    func navigate(to route: AppRoute) {
        navigationCoordinator.navigate(to: route)
    }

    func handleUnlockSuccess(vaultID: VaultID) {
        navigationCoordinator.handleUnlockSuccess(vaultID: vaultID)
    }

    func handleOnboardingFinished(vaultID: VaultID) {
        navigationCoordinator.finishOnboarding(vaultID: vaultID)
    }

    func handleLock(vaultID: VaultID) {
        navigationCoordinator.handleLock(vaultID: vaultID)
    }

    private func bindNavigationCoordinator() {
        navigationCoordinator.$route
            .assign(to: &$route)
        navigationCoordinator.$state
            .assign(to: &$appState)
        navigationCoordinator.$activeVaultID
            .assign(to: &$activeVaultID)
    }
}
