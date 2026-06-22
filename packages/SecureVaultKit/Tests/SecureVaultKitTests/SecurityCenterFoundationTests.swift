import Foundation
import XCTest
@testable import SecureVaultKit

final class SecurityCenterFoundationTests: XCTestCase {
    func testCurrentLockStateCanBeQueried() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let vaultID = try await createVault(using: engine)

        let unlockedStatus = try await engine.securityStatus()
        XCTAssertEqual(unlockedStatus.lockState, .unlocked)

        await engine.lockVault(id: vaultID)
        let lockedStatus = try await engine.securityStatus()
        XCTAssertEqual(lockedStatus.lockState, .locked)
    }

    func testAutoLockPolicyCanBeUpdated() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)

        try await engine.updateAutoLockPolicy(.fifteenMinutes)

        let status = try await engine.securityStatus()
        XCTAssertEqual(status.autoLockPolicy, .fifteenMinutes)
    }

    func testLockVaultLocksActiveSession() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)

        await engine.lockVault()

        let status = try await engine.securityStatus()
        XCTAssertEqual(status.lockState, .locked)
    }

    func testRecoveryStatusIsSafeAndIncompleteUntilRecoveryIsIntegrated() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)

        let status = try await engine.recoverySetupStatus()

        XCTAssertEqual(status, .incomplete)
    }

    func testTrustedDeviceSummaryExcludesRawKeysAndPermissions() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)

        let devices = try await engine.trustedDeviceSummaries()
        let encoded = try JSONEncoder().encode(devices)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(devices.count, 1)
        XCTAssertTrue(try XCTUnwrap(devices.first).isCurrentDevice)
        XCTAssertFalse(json.contains("publicKey"))
        XCTAssertFalse(json.contains("permissions"))
        XCTAssertFalse(json.contains("signature"))
    }

    func testSecurityStatusDoesNotExposeSessionMaterial() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await createVault(using: engine)

        let status = try await engine.securityStatus()
        let encoded = try JSONEncoder().encode(status)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertFalse(json.contains("keyReference"))
        XCTAssertFalse(json.contains("vaultEncryptionKey"))
        XCTAssertFalse(json.contains("recoverySecret"))
    }

    private func createVault(using engine: DefaultVaultEngine) async throws -> VaultID {
        try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
    }
}
