import Combine
import Foundation
import SecureVaultKit

@MainActor
final class UnlockViewModel: ObservableObject {
    @Published private(set) var state: UnlockState = .idle
    @Published private(set) var isRecoveryPlaceholderPresented = false
    private let unlockVaultUseCase: any UnlockVaultUsing
    private let errorMapper: any ErrorMapper

    init(
        unlockVaultUseCase: any UnlockVaultUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.unlockVaultUseCase = unlockVaultUseCase
        self.errorMapper = errorMapper
    }

    func unlock(vaultID: VaultID, method: UnlockMethod = .biometric) async {
        guard !state.isUnlocking else { return }
        state = .unlocking
        do {
            try await unlockVaultUseCase.execute(method: method)
            state = .unlocked(vaultID)
        } catch {
            state = .failed(userMessage(for: error))
        }
    }

    func showRecoveryPlaceholder() {
        isRecoveryPlaceholderPresented = true
    }

    func dismissRecoveryPlaceholder() {
        isRecoveryPlaceholderPresented = false
    }

    private func userMessage(for error: Error) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(title: "Unable to Unlock", message: "Unable to unlock vault.")
        ).message
    }
}
