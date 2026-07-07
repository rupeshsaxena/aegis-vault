import XCTest
import SecureVaultKit
@testable import AegisVault

@MainActor
final class AppNavigationStateMachineTests: XCTestCase {
    func testInitialStateLaunchesCorrectly() {
        let stateMachine = AppStateMachine()

        XCTAssertEqual(stateMachine.currentState, .launching)
    }

    func testOnboardingFinishRoutesToUnlocked() throws {
        var stateMachine = AppStateMachine(initialState: .onboarding)

        let state = try stateMachine.apply(.finishOnboarding)

        XCTAssertEqual(state, .unlocked)
        XCTAssertEqual(stateMachine.currentState, .unlocked)
    }

    func testLockedStateBlocksObjectDetail() {
        var stateMachine = AppStateMachine(initialState: .locked)
        let objectID = VaultObjectID("object")

        XCTAssertThrowsError(try stateMachine.apply(.showObjectDetail(objectID))) { error in
            XCTAssertEqual(
                error as? AppNavigationError,
                .illegalTransition(from: .locked, command: .showObjectDetail(objectID))
            )
        }
        XCTAssertEqual(stateMachine.currentState, .locked)
    }

    func testUnlockedStateAllowsObjectDetail() throws {
        var stateMachine = AppStateMachine(initialState: .unlocked)
        let objectID = VaultObjectID("object")

        let state = try stateMachine.apply(.showObjectDetail(objectID))

        XCTAssertEqual(state, .showingObjectDetail(objectID))
    }

    func testLockCommandRoutesToLocked() throws {
        var stateMachine = AppStateMachine(initialState: .unlocked)

        let state = try stateMachine.apply(.lockVault)

        XCTAssertEqual(state, .locked)
    }

    func testUnlockCommandRoutesToVaultHomeState() throws {
        var stateMachine = AppStateMachine(initialState: .locked)

        let state = try stateMachine.apply(.unlockVault)

        XCTAssertEqual(state, .unlocked)
    }

    func testTrashSettingsAndRecoveryCommandsRouteCorrectly() throws {
        var stateMachine = AppStateMachine(initialState: .unlocked)
        XCTAssertEqual(try stateMachine.apply(.showTrash), .trash)

        stateMachine.replaceState(.unlocked)
        XCTAssertEqual(try stateMachine.apply(.showSettings), .settings)

        stateMachine.replaceState(.unlocked)
        XCTAssertEqual(try stateMachine.apply(.showRecovery), .recovery)
    }

    func testIllegalTransitionProducesSafeFailure() {
        let coordinator = AppNavigationCoordinator()
        coordinator.setInitialRoute(.unlock(VaultID("vault")))

        let didNavigate = coordinator.handle(.showObjectDetail(VaultObjectID("object")))

        XCTAssertFalse(didNavigate)
        XCTAssertEqual(coordinator.state, .locked)
        XCTAssertNotNil(coordinator.navigationError)
        XCTAssertEqual(coordinator.route, .unlock(VaultID("vault")))
    }

    func testCoordinatorUnlockCommandRoutesToVaultHome() {
        let vaultID = VaultID("vault")
        let coordinator = AppNavigationCoordinator()
        coordinator.setInitialRoute(.unlock(vaultID))

        coordinator.handleUnlockSuccess(vaultID: vaultID)

        XCTAssertEqual(coordinator.state, .unlocked)
        XCTAssertEqual(coordinator.route, .vaultHome(vaultID))
    }
}
