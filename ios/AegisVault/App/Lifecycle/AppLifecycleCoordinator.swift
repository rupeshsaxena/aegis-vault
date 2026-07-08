import Foundation
import SecureVaultKit

@MainActor
final class AppLifecycleCoordinator: AppLifecycleObserver {
    private let getSecurityStatusUseCase: any GetSecurityStatusUsing
    private let lockVaultUseCase: any LockVaultUsing
    private let navigationCoordinator: AppNavigationCoordinator
    private var backgroundEnteredAt: Date?

    init(
        getSecurityStatusUseCase: any GetSecurityStatusUsing,
        lockVaultUseCase: any LockVaultUsing,
        navigationCoordinator: AppNavigationCoordinator
    ) {
        self.getSecurityStatusUseCase = getSecurityStatusUseCase
        self.lockVaultUseCase = lockVaultUseCase
        self.navigationCoordinator = navigationCoordinator
    }

    func handle(_ event: AppLifecycleEvent, now: Date) async {
        switch event {
        case .didBecomeActive:
            await lockIfExpiredSinceBackground(now: now)
        case .willResignActive:
            backgroundEnteredAt = backgroundEnteredAt ?? now
            await lockIfPolicyRequiresBackgroundLock(now: now)
        case .didEnterBackground:
            backgroundEnteredAt = now
            await lockIfPolicyRequiresBackgroundLock(now: now)
        case .willEnterForeground:
            await lockIfExpiredSinceBackground(now: now)
        case .willTerminate:
            await lockIfUnlocked()
        }
    }

    private func lockIfPolicyRequiresBackgroundLock(now: Date) async {
        guard let status = try? await getSecurityStatusUseCase.execute() else { return }
        guard status.lockState == .unlocked else { return }

        if status.autoLockPolicy == .immediately {
            await lock(status: status)
        }
    }

    private func lockIfExpiredSinceBackground(now: Date) async {
        guard let status = try? await getSecurityStatusUseCase.execute() else { return }
        guard status.lockState == .unlocked else {
            backgroundEnteredAt = nil
            return
        }
        guard let backgroundEnteredAt else { return }
        guard let timeout = timeout(for: status.autoLockPolicy) else { return }

        if now.timeIntervalSince(backgroundEnteredAt) >= timeout {
            await lock(status: status)
        }
    }

    private func lockIfUnlocked() async {
        guard let status = try? await getSecurityStatusUseCase.execute() else { return }
        guard status.lockState == .unlocked else { return }

        await lock(status: status)
    }

    private func lock(status: VaultSecurityStatus) async {
        await lockVaultUseCase.execute(vaultID: status.vaultId)
        navigationCoordinator.handleLock(vaultID: status.vaultId)
        backgroundEnteredAt = nil
    }

    private func timeout(for policy: AutoLockPolicy) -> TimeInterval? {
        switch policy {
        case .immediately:
            0
        case .oneMinute:
            60
        case .fiveMinutes:
            5 * 60
        case .fifteenMinutes:
            15 * 60
        case .never:
            nil
        }
    }
}
