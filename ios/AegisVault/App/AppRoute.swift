import SecureVaultKit

enum AppRoute: Hashable, Sendable {
    case onboarding
    case unlock(VaultID)
    case vaultHome(VaultID)
    case objectDetail(VaultObjectID)
    case objectEditor(VaultObjectID)
    case identityEditor(IdentityEditorMode)
    case importDocument(VaultID)
    case trash(VaultID)
    case settings(VaultID)
}
