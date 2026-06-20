import SecureVaultKit

struct UnlockState: Equatable {
    enum Phase: Equatable {
        case idle
        case unlocking
        case unlocked
        case failed
    }

    var phase: Phase = .idle
    var unlockedVaultID: VaultID?
    var errorMessage: String?
    var isUnlocking: Bool { phase == .unlocking }
}
