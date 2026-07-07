import SecureVaultKit

enum AppState: Equatable, Sendable {
    case launching
    case onboarding
    case locked
    case unlocked
    case showingObjectDetail(VaultObjectID)
    case editingObject(VaultObjectID?)
    case importingDocument
    case trash
    case settings
    case recovery
}
