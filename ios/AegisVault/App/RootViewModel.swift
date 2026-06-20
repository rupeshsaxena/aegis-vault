import Combine
import Foundation
import SecureVaultKit

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute?
    @Published private(set) var errorMessage: String?
    private let resolveAppRouteUseCase: any ResolveAppRouteUsing

    init(resolveAppRouteUseCase: any ResolveAppRouteUsing) {
        self.resolveAppRouteUseCase = resolveAppRouteUseCase
    }

    func resolveInitialRoute() async {
        guard route == nil else { return }
        do {
            route = try await resolveAppRouteUseCase.execute()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to open the vault."
        }
    }

    func navigate(to route: AppRoute) {
        self.route = route
    }

    func handleUnlockSuccess(vaultID: VaultID) {
        route = .vaultHome(vaultID)
    }

    func handleLock(vaultID: VaultID) {
        route = .unlock(vaultID)
    }
}
