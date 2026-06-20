import Combine
import Foundation
import SecureVaultKit

@MainActor
final class UnlockViewModel: ObservableObject {
    @Published private(set) var state = UnlockState()
    private let unlockVaultUseCase: any UnlockVaultUsing

    init(unlockVaultUseCase: any UnlockVaultUsing) {
        self.unlockVaultUseCase = unlockVaultUseCase
    }

    func unlock(vaultID: VaultID, method: UnlockMethod = .biometric) async {
        guard !state.isUnlocking else { return }
        state.phase = .unlocking
        state.errorMessage = nil
        do {
            try await unlockVaultUseCase.execute(vaultID: vaultID, method: method)
            state.unlockedVaultID = vaultID
            state.phase = .unlocked
        } catch {
            state.phase = .failed
            state.errorMessage = "Unable to unlock the vault."
        }
    }
}
