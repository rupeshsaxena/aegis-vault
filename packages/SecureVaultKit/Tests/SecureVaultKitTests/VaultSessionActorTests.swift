import Foundation
import XCTest
@testable import SecureVaultKit

final class VaultSessionActorTests: XCTestCase {
    func testInitialSessionStateIsLocked() async {
        let actor = VaultSessionActor()

        let state = await actor.currentState()
        XCTAssertEqual(state, .locked)
    }

    func testUnlockTransitionsToUnlocked() async {
        let actor = VaultSessionActor()

        await actor.unlock(session: makeSession())

        let state = await actor.currentState()
        XCTAssertEqual(state, .unlocked)
    }

    func testLockTransitionsToLocked() async {
        let actor = VaultSessionActor()
        await actor.unlock(session: makeSession())

        await actor.lock()

        let state = await actor.currentState()
        XCTAssertEqual(state, .locked)
    }

    func testRequireUnlockedFailsWhenLocked() async {
        let actor = VaultSessionActor()

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await actor.requireUnlocked()
        }
    }

    func testRequireUnlockedSucceedsWhenUnlocked() async throws {
        let actor = VaultSessionActor(autoLockPolicy: .never)
        let session = makeSession()
        await actor.unlock(session: session)

        let unlockedSession = try await actor.requireUnlocked()

        XCTAssertEqual(unlockedSession.vaultId, session.vaultId)
        XCTAssertEqual(unlockedSession.deviceId, session.deviceId)
        XCTAssertEqual(unlockedSession.keyReferences.vaultKeyReference, "vault-key-ref")
    }

    func testLastAccessedAtUpdatesOnRequireUnlocked() async throws {
        let actor = VaultSessionActor(autoLockPolicy: .never)
        let earlier = Date().addingTimeInterval(-60)
        await actor.unlock(session: makeSession(at: earlier))

        let session = try await actor.requireUnlocked()

        XCTAssertGreaterThan(session.lastAccessedAt, earlier)
    }

    func testSessionExpiresAccordingToPolicy() async {
        let start = Date(timeIntervalSince1970: 1_000)
        let actor = VaultSessionActor(autoLockPolicy: .oneMinute)
        await actor.unlock(session: makeSession(at: start))

        let beforeDeadline = await actor.isExpired(now: start.addingTimeInterval(59))
        let atDeadline = await actor.isExpired(now: start.addingTimeInterval(60))
        XCTAssertFalse(beforeDeadline)
        XCTAssertTrue(atDeadline)
    }

    func testLockIfExpiredLocksExpiredSession() async {
        let start = Date(timeIntervalSince1970: 1_000)
        let cleanupHandler = FakeSessionCleanupHandler()
        let actor = VaultSessionActor(autoLockPolicy: .oneMinute, cleanupHandler: cleanupHandler)
        await actor.unlock(session: makeSession(at: start))

        let didLock = await actor.lockIfExpired(now: start.addingTimeInterval(61))

        XCTAssertTrue(didLock)
        let state = await actor.currentState()
        let searchCount = await cleanupHandler.searchIndexClearCount
        XCTAssertEqual(state, .locked)
        XCTAssertEqual(searchCount, 1)
    }

    func testImmediateAutoLockExpiresImmediately() async {
        let start = Date(timeIntervalSince1970: 1_000)
        let actor = VaultSessionActor(autoLockPolicy: .never)
        await actor.unlock(session: makeSession(at: start))
        await actor.configureAutoLockPolicy(.immediately)

        let isExpired = await actor.isExpired(now: start)
        XCTAssertTrue(isExpired)
    }

    func testNeverAutoLockDoesNotExpire() async {
        let start = Date(timeIntervalSince1970: 1_000)
        let actor = VaultSessionActor(autoLockPolicy: .never)
        await actor.unlock(session: makeSession(at: start))

        let isExpired = await actor.isExpired(now: .distantFuture)
        XCTAssertFalse(isExpired)
    }

    func testLockRunsAllCleanupHooks() async {
        let cleanupHandler = FakeSessionCleanupHandler()
        let actor = VaultSessionActor(autoLockPolicy: .never, cleanupHandler: cleanupHandler)
        await actor.unlock(session: makeSession())

        await actor.lock()

        let searchCount = await cleanupHandler.searchIndexClearCount
        let previewCount = await cleanupHandler.previewCacheClearCount
        let thumbnailCount = await cleanupHandler.thumbnailCacheClearCount
        let objectCount = await cleanupHandler.decryptedObjectCacheClearCount
        XCTAssertEqual(searchCount, 1)
        XCTAssertEqual(previewCount, 1)
        XCTAssertEqual(thumbnailCount, 1)
        XCTAssertEqual(objectCount, 1)
    }

    private func makeSession(at date: Date = Date()) -> VaultSession {
        VaultSession(
            vaultId: VaultID("vault-1"),
            deviceId: DeviceID("device-1"),
            unlockedAt: date,
            lastAccessedAt: date,
            keyReferences: VaultSessionKeyReferences(vaultKeyReference: "vault-key-ref")
        )
    }
}

func XCTAssertThrowsVaultError(
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
