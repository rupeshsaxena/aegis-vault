import SecureVaultKit

enum AppRoute: Hashable, Sendable {
    case onboarding
    case unlock(VaultID)
    case vaultHome(VaultID)
    case objectDetail(VaultObjectID)
    case objectEditor(VaultObjectID)
    case secureNoteEditor(SecureNoteEditorMode)
    case identityEditor(IdentityEditorMode)
    case cardEditor(CardEditorMode)
    case importDocument(VaultID)
    case trash(VaultID)
    case settings(VaultID)
    case securityCenter(VaultID)
    case recoverySettings(VaultID)
}
