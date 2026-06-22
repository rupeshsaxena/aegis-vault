import Combine
import SecureVaultKit

@MainActor
final class SecurityCenterViewModel: ObservableObject {
    @Published private(set) var state: SecurityCenterState = .idle
    @Published private(set) var route: AppRoute?
    @Published private(set) var lockedVaultID: VaultID?

    private let getSecurityStatusUseCase: any GetSecurityStatusUsing
    private let updateAutoLockPolicyUseCase: any UpdateAutoLockPolicyUsing
    private let lockVaultUseCase: any LockVaultUsing

    init(
        getSecurityStatusUseCase: any GetSecurityStatusUsing,
        updateAutoLockPolicyUseCase: any UpdateAutoLockPolicyUsing,
        lockVaultUseCase: any LockVaultUsing
    ) {
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
        self.updateAutoLockPolicyUseCase = updateAutoLockPolicyUseCase
        self.lockVaultUseCase = lockVaultUseCase
    }

    func loadSecurityStatus() async {
        state = .loading
        do {
            state = .loaded(
                SecurityStatusViewData(status: try await getSecurityStatusUseCase.execute())
            )
        } catch {
            state = .failed("Unable to load security status.")
        }
    }

    func updateAutoLockPolicy(_ policy: AutoLockPolicy) async {
        do {
            try await updateAutoLockPolicyUseCase.execute(policy: policy)
            guard case .loaded(var status) = state else {
                await loadSecurityStatus()
                return
            }
            status = SecurityStatusViewData(
                lockState: status.lockState,
                autoLockPolicy: policy,
                biometricStatus: status.biometricStatus,
                passkeyStatus: status.passkeyStatus,
                recoveryStatus: status.recoveryStatus,
                trustedDevices: status.trustedDevices
            )
            state = .loaded(status)
        } catch {
            state = .failed("Unable to update auto-lock.")
        }
    }

    func lock(vaultID: VaultID) async {
        await lockVaultUseCase.execute(vaultID: vaultID)
        lockedVaultID = vaultID
    }

    func close(vaultID: VaultID) {
        route = .settings(vaultID)
    }

    func clearRoute() {
        route = nil
    }
}
