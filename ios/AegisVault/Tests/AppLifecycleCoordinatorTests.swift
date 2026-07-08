import Foundation
import SecureVaultKit
import XCTest
@testable import AegisVault

@MainActor
final class AppLifecycleCoordinatorTests: XCTestCase {
    func testDidEnterBackgroundWithImmediatePolicyLocksVault() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .immediately, lockState: .unlocked)
            ]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [vaultID])
        XCTAssertEqual(navigationCoordinator.state, .locked)
        XCTAssertEqual(navigationCoordinator.route, .unlock(vaultID))
    }

    func testDidEnterBackgroundWithNeverPolicyDoesNotLock() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .never, lockState: .unlocked)
            ]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [])
        XCTAssertEqual(navigationCoordinator.state, .unlocked)
        XCTAssertEqual(navigationCoordinator.route, .vaultHome(vaultID))
    }

    func testWillEnterForegroundAfterExpiredSessionLocks() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        let status = makeStatus(vaultID: vaultID, policy: .oneMinute, lockState: .unlocked)
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [status, status]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))
        await coordinator.handle(.willEnterForeground, now: Date(timeIntervalSince1970: 1_061))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [vaultID])
        XCTAssertEqual(navigationCoordinator.state, .locked)
    }

    func testWillEnterForegroundBeforePolicyExpiryDoesNotLock() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        let status = makeStatus(vaultID: vaultID, policy: .fiveMinutes, lockState: .unlocked)
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [status, status]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))
        await coordinator.handle(.willEnterForeground, now: Date(timeIntervalSince1970: 1_299))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [])
        XCTAssertEqual(navigationCoordinator.state, .unlocked)
    }

    func testWillEnterForegroundWhenAlreadyLockedRemainsLocked() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.unlock(vaultID))
        let status = makeStatus(vaultID: vaultID, policy: .oneMinute, lockState: .locked)
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [status]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.willEnterForeground, now: Date(timeIntervalSince1970: 1_061))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [])
        XCTAssertEqual(navigationCoordinator.state, .locked)
    }

    func testAutoLockFromSensitiveRouteTransitionsAppStateToLocked() async {
        let vaultID = VaultID("vault")
        let objectID = VaultObjectID("object")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        navigationCoordinator.navigate(to: .objectDetail(objectID))
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .immediately, lockState: .unlocked)
            ]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(navigationCoordinator.state, .locked)
        XCTAssertEqual(navigationCoordinator.route, .unlock(vaultID))
    }

    func testLifecycleCoordinatorCallsLockVaultUseCase() async {
        let vaultID = VaultID("vault")
        let lockUseCase = LifecycleLockUseCase()
        let navigationCoordinator = AppNavigationCoordinator()
        navigationCoordinator.setInitialRoute(.vaultHome(vaultID))
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .immediately, lockState: .unlocked)
            ]),
            lockUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator
        )

        await coordinator.handle(.willResignActive, now: Date(timeIntervalSince1970: 1_000))

        let receivedIDs = await lockUseCase.receivedIDs()
        XCTAssertEqual(receivedIDs, [vaultID])
    }

    func testPrivacyShieldActivatesOnWillResignActive() async {
        let vaultID = VaultID("vault")
        let privacyShieldController = PrivacyShieldController()
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .never, lockState: .unlocked)
            ]),
            lockUseCase: LifecycleLockUseCase(),
            navigationCoordinator: AppNavigationCoordinator(),
            privacyShieldController: privacyShieldController
        )

        await coordinator.handle(.willResignActive, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertTrue(privacyShieldController.isShieldVisible)
    }

    func testPrivacyShieldActivatesOnDidEnterBackground() async {
        let vaultID = VaultID("vault")
        let privacyShieldController = PrivacyShieldController()
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .never, lockState: .unlocked)
            ]),
            lockUseCase: LifecycleLockUseCase(),
            navigationCoordinator: AppNavigationCoordinator(),
            privacyShieldController: privacyShieldController
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertTrue(privacyShieldController.isShieldVisible)
    }

    func testPrivacyShieldDismissesOnDidBecomeActive() async {
        let vaultID = VaultID("vault")
        let privacyShieldController = PrivacyShieldController()
        privacyShieldController.activateForBackgroundState()
        let coordinator = makeCoordinator(
            statusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .never, lockState: .unlocked)
            ]),
            lockUseCase: LifecycleLockUseCase(),
            navigationCoordinator: AppNavigationCoordinator(),
            privacyShieldController: privacyShieldController
        )

        await coordinator.handle(.didBecomeActive, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertFalse(privacyShieldController.isShieldVisible)
    }

    func testLifecycleCoordinatorClearsSensitivePresentationStateOnBackground() async {
        let vaultID = VaultID("vault")
        var resetCount = 0
        let coordinator = AppLifecycleCoordinator(
            getSecurityStatusUseCase: LifecycleSecurityStatusUseCase(statuses: [
                makeStatus(vaultID: vaultID, policy: .never, lockState: .unlocked)
            ]),
            lockVaultUseCase: LifecycleLockUseCase(),
            navigationCoordinator: AppNavigationCoordinator(),
            privacyShieldController: PrivacyShieldController(),
            sensitiveStateResetHandler: {
                resetCount += 1
            }
        )

        await coordinator.handle(.didEnterBackground, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(resetCount, 1)
    }

    func testLifecycleCoordinatorDoesNotAccessInfrastructureServices() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("App/Lifecycle/AppLifecycleCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("StorageEngine"))
        XCTAssertFalse(source.contains("CryptoEngine"))
        XCTAssertFalse(source.contains("BlobStore"))
        XCTAssertFalse(source.contains("Repository"))
    }

    private func makeCoordinator(
        statusUseCase: LifecycleSecurityStatusUseCase,
        lockUseCase: LifecycleLockUseCase,
        navigationCoordinator: AppNavigationCoordinator,
        privacyShieldController: PrivacyShieldController? = nil
    ) -> AppLifecycleCoordinator {
        AppLifecycleCoordinator(
            getSecurityStatusUseCase: statusUseCase,
            lockVaultUseCase: lockUseCase,
            navigationCoordinator: navigationCoordinator,
            privacyShieldController: privacyShieldController
        )
    }

    private func makeStatus(
        vaultID: VaultID,
        policy: AutoLockPolicy,
        lockState: VaultSessionState
    ) -> VaultSecurityStatus {
        VaultSecurityStatus(
            vaultId: vaultID,
            lockState: lockState,
            autoLockPolicy: policy,
            biometricStatus: .notConfigured,
            passkeyStatus: .notConfigured,
            recoveryStatus: .incomplete,
            trustedDevices: []
        )
    }
}

private actor LifecycleSecurityStatusUseCase: GetSecurityStatusUsing {
    private var statuses: [VaultSecurityStatus]

    init(statuses: [VaultSecurityStatus]) {
        self.statuses = statuses
    }

    func execute() async throws -> VaultSecurityStatus {
        if statuses.count > 1 {
            return statuses.removeFirst()
        }

        guard let status = statuses.first else {
            throw LifecycleTestError.missingStatus
        }
        return status
    }
}

private actor LifecycleLockUseCase: LockVaultUsing {
    private var vaultIDs: [VaultID] = []

    func execute(vaultID: VaultID) async {
        vaultIDs.append(vaultID)
    }

    func receivedIDs() -> [VaultID] {
        vaultIDs
    }
}

private enum LifecycleTestError: Error {
    case missingStatus
}
