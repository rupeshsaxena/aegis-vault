import SecureVaultKit

enum AppNavigationCommand: Equatable, Sendable {
    case finishOnboarding
    case lockVault
    case unlockVault
    case showVaultHome
    case showObjectDetail(VaultObjectID)
    case createSecureNote
    case editObject(VaultObjectID)
    case importDocument
    case showTrash
    case showSettings
    case showRecovery
}

enum AppNavigationError: Error, Equatable, Sendable {
    case illegalTransition(from: AppState, command: AppNavigationCommand)
    case missingActiveVault(command: AppNavigationCommand)
}
