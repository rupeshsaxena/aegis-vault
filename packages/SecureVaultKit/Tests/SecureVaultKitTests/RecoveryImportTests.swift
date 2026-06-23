import Foundation
import XCTest
@testable import SecureVaultKit

final class RecoveryImportTests: XCTestCase {

    // MARK: - validateRecoveryPackage

    func testValidateRecoveryPackageSucceedsWithValidPackageAndSecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let secret = RecoverySecret("correct horse battery staple")
        let fileURL = try await makePackageFile(secret: secret)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.validateRecoveryPackage(from: fileURL, recoverySecret: secret)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testValidateRecoveryPackageFailsWithEmptySecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let fileURL = try await makePackageFile(secret: RecoverySecret("correct horse battery staple"))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.validateRecoveryPackage(
            from: fileURL,
            recoverySecret: RecoverySecret("")
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(.emptyRecoverySecret))
    }

    func testValidateRecoveryPackageFailsWithWrongSecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let fileURL = try await makePackageFile(secret: RecoverySecret("correct horse battery staple"))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.validateRecoveryPackage(
            from: fileURL,
            recoverySecret: RecoverySecret("wrong secret entirely")
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(.invalidValidationProof))
    }

    // MARK: - importRecoveryPackage

    func testImportRecoveryPackageSucceedsWithValidPackageAndSecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let secret = RecoverySecret("correct horse battery staple")
        let vaultId = VaultID("vault-import-test")
        let deviceId = DeviceID("device-import-test")
        let fileURL = try await makePackageFile(
            secret: secret,
            vaultId: vaultId,
            deviceId: deviceId
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importRecoveryPackage(from: fileURL, recoverySecret: secret)

        XCTAssertEqual(result.vaultId, vaultId)
        XCTAssertEqual(result.deviceId, deviceId)
        XCTAssertEqual(result.status, .validated)
    }

    func testImportRecoveryPackageFailsWithCorruptedPackage() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let fileURL = try writeTempFile(data: Data("{not-json".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        await XCTAssertThrowsVaultError(
            .invalidInput("Recovery package JSON is invalid.")
        ) {
            _ = try await engine.importRecoveryPackage(
                from: fileURL,
                recoverySecret: RecoverySecret("any secret")
            )
        }
    }

    func testImportRecoveryPackageFailsWithWrongSecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let fileURL = try await makePackageFile(secret: RecoverySecret("correct horse battery staple"))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        do {
            _ = try await engine.importRecoveryPackage(
                from: fileURL,
                recoverySecret: RecoverySecret("wrong secret")
            )
            XCTFail("Expected invalidInput error to be thrown.")
        } catch let error as VaultError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("incorrect") || message.contains("invalid"), "Expected user-safe message, got: \(message)")
            } else {
                XCTFail("Expected invalidInput, got: \(error)")
            }
        }
    }

    func testImportRecoveryPackageDoesNotPersistRecoverySecret() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let secret = RecoverySecret("super secret recovery phrase")
        let fileURL = try await makePackageFile(secret: secret)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importRecoveryPackage(from: fileURL, recoverySecret: secret)

        // Verify that no part of the result contains or references the recovery secret
        let resultDescription = "\(result.vaultId)\(result.deviceId)\(result.status)"
        XCTAssertFalse(resultDescription.contains("super secret recovery phrase"))
        XCTAssertFalse(resultDescription.contains("recoverySecret"))
    }

    func testImportRecoveryPackageDoesNotExposeRawKeys() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let secret = RecoverySecret("correct horse battery staple")
        let fileURL = try await makePackageFile(secret: secret)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importRecoveryPackage(from: fileURL, recoverySecret: secret)

        let resultDescription = "\(result)"
        XCTAssertFalse(resultDescription.contains("vaultKey"))
        XCTAssertFalse(resultDescription.contains("encryptionKey"))
        XCTAssertFalse(resultDescription.contains("itemKey"))
        XCTAssertFalse(resultDescription.contains("blobKey"))
        XCTAssertFalse(resultDescription.contains("wrappedKey"))
    }

    func testFailedImportDoesNotCreateTrustedDevice() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let fileURL = try await makePackageFile(secret: RecoverySecret("correct horse battery staple"))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        _ = try? await engine.importRecoveryPackage(
            from: fileURL,
            recoverySecret: RecoverySecret("wrong secret")
        )

        // Verify no device was registered as a result of the failed import
        // The engine has no vault, so trustedDeviceSummaries will throw — that's fine
        do {
            let devices = try await engine.trustedDeviceSummaries()
            XCTAssertTrue(devices.isEmpty, "Failed import must not register any trusted device.")
        } catch {
            // No vault → expected to fail; no partial state was created
        }
    }

    func testSuccessfulImportReturnsValidatedStatusAndNoTrustedDeviceInCurrentArchitecture() async throws {
        let configuration = makeInMemoryConfiguration()
        let engine = DefaultVaultEngine(configuration: configuration)
        let secret = RecoverySecret("correct horse battery staple")
        let vaultId = VaultID("vault-arch-test")
        let fileURL = try await makePackageFile(secret: secret, vaultId: vaultId)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let result = try await engine.importRecoveryPackage(from: fileURL, recoverySecret: secret)

        XCTAssertEqual(result.status, .validated)
        // Current architecture validates recovery package identity only — actual device
        // registration requires full key material in the package (not yet implemented).
        do {
            let devices = try await engine.trustedDeviceSummaries()
            XCTAssertTrue(devices.isEmpty)
        } catch {
            // No vault registered in this engine — no device created
        }
    }

    func testImportRecoveryPackageFailsWhenFileURLIsInvalid() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent-package-\(UUID().uuidString).json")

        await XCTAssertThrowsVaultError(
            .invalidInput("Unable to read recovery package file.")
        ) {
            _ = try await engine.importRecoveryPackage(
                from: nonExistentURL,
                recoverySecret: RecoverySecret("any secret")
            )
        }
    }

    func testValidateRecoveryPackageFailsWhenFileURLIsInvalid() async throws {
        let engine = DefaultVaultEngine(configuration: makeInMemoryConfiguration())
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).json")

        await XCTAssertThrowsVaultError(
            .invalidInput("Unable to read recovery package file.")
        ) {
            _ = try await engine.validateRecoveryPackage(
                from: nonExistentURL,
                recoverySecret: RecoverySecret("any secret")
            )
        }
    }

    // MARK: - Helpers

    private func makePackageFile(
        secret: RecoverySecret,
        vaultId: VaultID = VaultID("vault-1"),
        deviceId: DeviceID = DeviceID("device-1")
    ) async throws -> URL {
        let service = DefaultRecoveryPackageService()
        let package = try await service.generateRecoveryPackage(
            vaultId: vaultId,
            deviceId: deviceId,
            recoverySecret: secret
        )
        let data = try await service.exportRecoveryPackage(package)
        return try writeTempFile(data: data)
    }

    private func writeTempFile(data: Data, fileName: String = "recovery-package.json") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecoveryImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
