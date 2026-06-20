import SecureVaultKit

enum UnlockState: Equatable {
    case idle
    case unlocking
    case unlocked(VaultID)
    case failed(String)

    var isUnlocking: Bool {
        self == .unlocking
    }

    var unlockedVaultID: VaultID? {
        guard case .unlocked(let vaultID) = self else { return nil }
        return vaultID
    }

    var errorMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }
}
