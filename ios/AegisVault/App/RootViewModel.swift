import Combine
import Foundation
import SecureVaultKit

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var route: AppRoute?
    @Published private(set) var errorMessage: String?
    @Published private(set) var activeVaultID: VaultID?
    private let resolveAppRouteUseCase: any ResolveAppRouteUsing

    init(resolveAppRouteUseCase: any ResolveAppRouteUsing) {
        self.resolveAppRouteUseCase = resolveAppRouteUseCase
    }

    func resolveInitialRoute() async {
        guard route == nil else { return }
        do {
            let resolvedRoute = try await resolveAppRouteUseCase.execute()
            route = resolvedRoute
            updateActiveVaultID(from: resolvedRoute)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to open the vault."
        }
    }

    func navigate(to route: AppRoute) {
        self.route = route
        updateActiveVaultID(from: route)
    }

    func handleUnlockSuccess(vaultID: VaultID) {
        activeVaultID = vaultID
        route = .vaultHome(vaultID)
    }

    func handleLock(vaultID: VaultID) {
        activeVaultID = vaultID
        route = .unlock(vaultID)
    }

    private func updateActiveVaultID(from route: AppRoute) {
        switch route {
        case .unlock(let vaultID), .vaultHome(let vaultID), .importDocument(let vaultID),
             .trash(let vaultID), .settings(let vaultID), .securityCenter(let vaultID),
             .recoverySettings(let vaultID):
            activeVaultID = vaultID
        case .secureNoteEditor(.create(let vaultID)), .identityEditor(.create(let vaultID)),
             .cardEditor(.create(let vaultID)):
            activeVaultID = vaultID
        case .onboarding:
            activeVaultID = nil
        case .objectDetail, .objectEditor, .secureNoteEditor(.edit),
             .identityEditor(.edit), .cardEditor(.edit):
            break
        }
    }
}
