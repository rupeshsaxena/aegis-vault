import Combine
import Foundation
import SecureVaultKit

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var route: AppRoute?
    @Published private(set) var activeVaultID: VaultID?
    @Published private(set) var navigationError: AppNavigationError?

    private var stateMachine: AppStateMachine

    init(stateMachine: AppStateMachine = AppStateMachine()) {
        self.stateMachine = stateMachine
        state = stateMachine.currentState
    }

    func setInitialRoute(_ route: AppRoute) {
        let state = AppState(route: route)
        stateMachine.replaceState(state)
        self.state = state
        self.route = route
        updateActiveVaultID(from: route)
        navigationError = nil
    }

    func finishOnboarding(vaultID: VaultID) {
        activeVaultID = vaultID
        handle(.finishOnboarding, preferredRoute: .vaultHome(vaultID))
    }

    func handleUnlockSuccess(vaultID: VaultID) {
        activeVaultID = vaultID
        handle(.unlockVault, preferredRoute: .vaultHome(vaultID))
    }

    func handleLock(vaultID: VaultID) {
        activeVaultID = vaultID
        handle(.lockVault, preferredRoute: .unlock(vaultID))
    }

    func navigate(to route: AppRoute) {
        let command = AppNavigationCommand(route: route)
        updateActiveVaultID(from: route)
        handle(command, preferredRoute: route)
    }

    @discardableResult
    func handle(_ command: AppNavigationCommand) -> Bool {
        handle(command, preferredRoute: route(for: command))
    }

    @discardableResult
    private func handle(_ command: AppNavigationCommand, preferredRoute: AppRoute?) -> Bool {
        do {
            let nextState = try stateMachine.apply(command)
            guard let nextRoute = preferredRoute else {
                let error = AppNavigationError.missingActiveVault(command: command)
                navigationError = error
                stateMachine.replaceState(state)
                return false
            }

            state = nextState
            route = nextRoute
            updateActiveVaultID(from: nextRoute)
            navigationError = nil
            return true
        } catch let error as AppNavigationError {
            navigationError = error
            return false
        } catch {
            navigationError = .illegalTransition(from: state, command: command)
            return false
        }
    }

    private func route(for command: AppNavigationCommand) -> AppRoute? {
        switch command {
        case .finishOnboarding, .unlockVault, .showVaultHome:
            return activeVaultID.map(AppRoute.vaultHome)
        case .lockVault:
            return activeVaultID.map(AppRoute.unlock)
        case .showObjectDetail(let objectID):
            return .objectDetail(objectID)
        case .createSecureNote:
            return activeVaultID.map { .secureNoteEditor(.create($0)) }
        case .editObject(let objectID):
            return .objectEditor(objectID)
        case .importDocument:
            return activeVaultID.map(AppRoute.importDocument)
        case .showTrash:
            return activeVaultID.map(AppRoute.trash)
        case .showSettings:
            return activeVaultID.map(AppRoute.settings)
        case .showRecovery:
            return activeVaultID.map(AppRoute.recoverySettings)
        }
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

private extension AppState {
    init(route: AppRoute) {
        switch route {
        case .onboarding:
            self = .onboarding
        case .unlock:
            self = .locked
        case .vaultHome:
            self = .unlocked
        case .objectDetail(let objectID):
            self = .showingObjectDetail(objectID)
        case .objectEditor(let objectID), .secureNoteEditor(.edit(let objectID)),
             .identityEditor(.edit(let objectID)), .cardEditor(.edit(let objectID)):
            self = .editingObject(objectID)
        case .secureNoteEditor(.create), .identityEditor(.create), .cardEditor(.create):
            self = .editingObject(nil)
        case .importDocument:
            self = .importingDocument
        case .trash:
            self = .trash
        case .settings, .securityCenter:
            self = .settings
        case .recoverySettings:
            self = .recovery
        }
    }
}

private extension AppNavigationCommand {
    init(route: AppRoute) {
        switch route {
        case .onboarding:
            self = .showVaultHome
        case .unlock:
            self = .lockVault
        case .vaultHome:
            self = .showVaultHome
        case .objectDetail(let objectID):
            self = .showObjectDetail(objectID)
        case .objectEditor(let objectID), .secureNoteEditor(.edit(let objectID)),
             .identityEditor(.edit(let objectID)), .cardEditor(.edit(let objectID)):
            self = .editObject(objectID)
        case .secureNoteEditor(.create), .identityEditor(.create), .cardEditor(.create):
            self = .createSecureNote
        case .importDocument:
            self = .importDocument
        case .trash:
            self = .showTrash
        case .settings, .securityCenter:
            self = .showSettings
        case .recoverySettings:
            self = .showRecovery
        }
    }
}
