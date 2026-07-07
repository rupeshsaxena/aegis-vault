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
    private let errorMapper: any ErrorMapper

    init(
        getSecurityStatusUseCase: any GetSecurityStatusUsing,
        updateAutoLockPolicyUseCase: any UpdateAutoLockPolicyUsing,
        lockVaultUseCase: any LockVaultUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper()
    ) {
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
        self.updateAutoLockPolicyUseCase = updateAutoLockPolicyUseCase
        self.lockVaultUseCase = lockVaultUseCase
        self.errorMapper = errorMapper
    }

    func loadSecurityStatus() async {
        state = .loading
        do {
            state = .loaded(
                SecurityStatusViewData(status: try await getSecurityStatusUseCase.execute())
            )
        } catch {
            state = .failed(errorMapper.userMessage(
                for: error,
                fallback: UserMessage(title: "Unable to Load Security", message: "Unable to load security status.")
            ).message)
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
            state = .failed(errorMapper.userMessage(
                for: error,
                fallback: UserMessage(title: "Unable to Update Auto-Lock", message: "Unable to update auto-lock.")
            ).message)
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
