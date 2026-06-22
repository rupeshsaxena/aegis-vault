import Foundation
import XCTest
@testable import SecureVaultKit

final class RecoveryExportTests: XCTestCase {
    func testGetRecoveryStatusFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.getRecoveryStatus()
        }
    }

    func testExportRecoveryPackageFailsWhenLocked() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())

        await XCTAssertThrowsVaultError(.locked) {
            _ = try await engine.exportRecoveryPackage(acknowledgingRisk: true)
        }
    }

    func testExportRecoveryPackageRequiresAcknowledgment() async throws {
        let engine = try await makeUnlockedEngine()

        await XCTAssertThrowsVaultError(
            .invalidInput("Recovery export requires explicit acknowledgment.")
        ) {
            _ = try await engine.exportRecoveryPackage(acknowledgingRisk: false)
        }
    }

    func testExportRecoveryPackageContainsNoForbiddenSensitiveMaterial() async throws {
        let engine = try await makeUnlockedEngine()
        let export = try await engine.exportRecoveryPackage(acknowledgingRisk: true)
        let fileURL = try XCTUnwrap(export.temporaryFileURL)
        let content = try String(contentsOf: fileURL, encoding: .utf8).lowercased()

        XCTAssertFalse(content.contains("recoverysecret"))
        XCTAssertFalse(content.contains("rootvaultkey"))
        XCTAssertFalse(content.contains("vaultencryptionkey"))
        XCTAssertFalse(content.contains("itemkey"))
        XCTAssertFalse(content.contains("blobkey"))
        XCTAssertFalse(content.contains("payload"))
        XCTAssertFalse(content.contains("blobdata"))
        await engine.lockVault()
    }

    func testExportRecoveryPackageReturnsVersionedPackage() async throws {
        let engine = try await makeUnlockedEngine()
        let export = try await engine.exportRecoveryPackage(acknowledgingRisk: true)
        let fileURL = try XCTUnwrap(export.temporaryFileURL)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]

        XCTAssertEqual(export.formatVersion, 1)
        XCTAssertEqual(json?["packageVersion"] as? Int, 1)
        await engine.lockVault()
    }

    func testExportRecoveryPackageUpdatesLastExportedAt() async throws {
        let engine = try await makeUnlockedEngine()
        let initialStatus = try await engine.getRecoveryStatus()
        XCTAssertNil(initialStatus.lastExportedAt)

        let export = try await engine.exportRecoveryPackage(acknowledgingRisk: true)
        let status = try await engine.getRecoveryStatus()

        XCTAssertEqual(status.lastExportedAt, export.exportedAt)
        XCTAssertFalse(status.isConfigured)
        await engine.lockVault()
    }

    func testExportRecoveryPackageAppendsAuditEventWithoutSensitiveMetadata() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultID = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )

        let export = try await engine.exportRecoveryPackage(acknowledgingRisk: true)

        let events = try await configuration.eventEngine.listEvents(for: vaultID)
        let event = try XCTUnwrap(events.last { $0.type == .recoveryPackageExported })
        XCTAssertEqual(event.occurredAt, export.exportedAt)
        XCTAssertNil(event.objectId)
        XCTAssertNil(event.blobId)
        await engine.lockVault()
    }

    func testLockRemovesTemporaryRecoveryExport() async throws {
        let engine = try await makeUnlockedEngine()
        let export = try await engine.exportRecoveryPackage(acknowledgingRisk: true)
        let fileURL = try XCTUnwrap(export.temporaryFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        await engine.lockVault()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeUnlockedEngine() async throws -> DefaultVaultEngine {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        _ = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        return engine
    }
}
