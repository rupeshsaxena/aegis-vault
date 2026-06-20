import Foundation
import SecureVaultKit

struct OnboardingState: Equatable {
    enum Phase: Equatable {
        case idle
        case creating
        case created
        case failed
    }

    var vaultName = ""
    var phase: Phase = .idle
    var createdVaultID: VaultID?
    var errorMessage: String?
    var canCreateVault: Bool {
        !vaultName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase != .creating
    }
}
