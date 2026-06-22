import SecureVaultKit

enum RootRoute: Equatable, Sendable {
    case onboarding
    case unlock(VaultID)
    case vaultHome(VaultID)
}
