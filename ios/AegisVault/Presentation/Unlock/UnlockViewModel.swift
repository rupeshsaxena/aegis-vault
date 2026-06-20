import Combine
import Foundation
import SecureVaultKit

@MainActor
final class UnlockViewModel: ObservableObject {
    @Published private(set) var state: UnlockState = .idle
    @Published private(set) var isRecoveryPlaceholderPresented = false
    private let unlockVaultUseCase: any UnlockVaultUsing

    init(unlockVaultUseCase: any UnlockVaultUsing) {
        self.unlockVaultUseCase = unlockVaultUseCase
    }

    func unlock(vaultID: VaultID, method: UnlockMethod = .biometric) async {
        guard !state.isUnlocking else { return }
        state = .unlocking
        do {
            try await unlockVaultUseCase.execute(method: method)
            state = .unlocked(vaultID)
        } catch {
            state = .failed(Self.userMessage(for: error))
        }
    }

    func showRecoveryPlaceholder() {
        isRecoveryPlaceholderPresented = true
    }

    func dismissRecoveryPlaceholder() {
        isRecoveryPlaceholderPresented = false
    }

    nonisolated static func userMessage(for error: Error) -> String {
        guard let vaultError = error as? VaultError else {
            return "Unable to unlock vault."
        }
        switch vaultError {
        case .locked:
            return "Your vault is locked."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .vaultNotFound:
            return "No vault was found on this device."
        default:
            return "Unable to unlock vault."
        }
    }
}
