import Foundation

struct AppStateMachine: Sendable {
    private(set) var currentState: AppState

    init(initialState: AppState = .launching) {
        currentState = initialState
    }

    mutating func replaceState(_ state: AppState) {
        currentState = state
    }

    @discardableResult
    mutating func apply(_ command: AppNavigationCommand) throws -> AppState {
        guard let nextState = nextState(for: command) else {
            throw AppNavigationError.illegalTransition(from: currentState, command: command)
        }

        currentState = nextState
        return nextState
    }

    private func nextState(for command: AppNavigationCommand) -> AppState? {
        switch command {
        case .finishOnboarding:
            return currentState == .onboarding || currentState == .launching ? .unlocked : nil
        case .lockVault:
            return isUnlockedContext ? .locked : nil
        case .unlockVault:
            return currentState == .locked || currentState == .launching ? .unlocked : nil
        case .showVaultHome:
            return isUnlockedContext ? .unlocked : nil
        case .showObjectDetail(let objectID):
            return isUnlockedContext ? .showingObjectDetail(objectID) : nil
        case .createSecureNote:
            return isUnlockedContext ? .editingObject(nil) : nil
        case .editObject(let objectID):
            return isUnlockedContext ? .editingObject(objectID) : nil
        case .importDocument:
            return isUnlockedContext ? .importingDocument : nil
        case .showTrash:
            return isUnlockedContext ? .trash : nil
        case .showSettings:
            return isUnlockedContext ? .settings : nil
        case .showRecovery:
            return isUnlockedContext ? .recovery : nil
        }
    }

    private var isUnlockedContext: Bool {
        switch currentState {
        case .unlocked, .showingObjectDetail, .editingObject, .importingDocument,
             .trash, .settings, .recovery:
            return true
        case .launching, .onboarding, .locked:
            return false
        }
    }
}
