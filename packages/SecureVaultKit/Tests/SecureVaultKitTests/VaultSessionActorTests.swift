import XCTest
@testable import SecureVaultKit

final class VaultSessionActorTests: XCTestCase {
    func testLockedSessionRejectsRequireUnlocked() async {
        let actor = VaultSessionActor()

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await actor.requireUnlocked()
        }
    }

    func testUnlockStoresSession() async throws {
        let actor = VaultSessionActor()
        let session = VaultSession(
            vaultId: VaultID("vault-1"),
            deviceId: DeviceID("device-1"),
            keyReferences: VaultSessionKeyReferences(vaultKeyReference: "vault-key-ref")
        )

        await actor.unlock(session: session)

        let unlockedSession = try await actor.requireUnlocked()
        XCTAssertEqual(unlockedSession.vaultId, session.vaultId)
        XCTAssertEqual(unlockedSession.deviceId, session.deviceId)
        XCTAssertEqual(unlockedSession.lockState, .unlocked)
        XCTAssertEqual(unlockedSession.keyReferences.vaultKeyReference, "vault-key-ref")
    }

    func testLockClearsSession() async throws {
        let actor = VaultSessionActor()
        let session = VaultSession(vaultId: VaultID("vault-1"), deviceId: DeviceID("device-1"))

        await actor.unlock(session: session)
        await actor.lock()

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await actor.requireUnlocked()
        }
    }

    func testCurrentStateReturnsLockedAndUnlockedCorrectly() async {
        let actor = VaultSessionActor()
        let session = VaultSession(vaultId: VaultID("vault-1"), deviceId: DeviceID("device-1"))

        let initialState = await actor.currentState()
        XCTAssertEqual(initialState, .locked)

        await actor.unlock(session: session)

        switch await actor.currentState() {
        case .locked:
            XCTFail("Expected unlocked state.")
        case .unlocked(let currentSession):
            XCTAssertEqual(currentSession.vaultId, session.vaultId)
            XCTAssertEqual(currentSession.lockState, .unlocked)
        }
    }
}

private func XCTAssertThrowsVaultError(
    _ expectedError: VaultError,
    file: StaticString = #filePath,
    line: UInt = #line,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail("Expected \(expectedError) to be thrown.", file: file, line: line)
    } catch let error as VaultError {
        XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {
        XCTFail("Expected \(expectedError), got \(error).", file: file, line: line)
    }
}
