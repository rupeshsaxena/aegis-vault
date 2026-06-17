import Foundation
import XCTest
@testable import SecureVaultKit

final class RecoveryPackageServiceTests: XCTestCase {
    func testRecoveryPackageGeneration() async throws {
        let service = DefaultRecoveryPackageService()
        let vaultId = VaultID("vault-1")
        let deviceId = DeviceID("device-1")

        let package = try await service.generateRecoveryPackage(
            vaultId: vaultId,
            deviceId: deviceId,
            recoverySecret: RecoverySecret("correct horse battery staple")
        )

        XCTAssertEqual(package.formatVersion, DefaultRecoveryPackageService.supportedFormatVersion)
        XCTAssertEqual(package.vaultId, vaultId)
        XCTAssertEqual(package.deviceId, deviceId)
        XCTAssertFalse(package.packageId.isEmpty)
        XCTAssertFalse(package.validationProof.isEmpty)
    }

    func testRecoveryPackageExportImportRoundTripsJSON() async throws {
        let service = DefaultRecoveryPackageService()
        let package = try await makePackage(using: service)

        let exported = try await service.exportRecoveryPackage(package)
        let imported = try await service.importRecoveryPackage(from: exported)

        XCTAssertEqual(imported, package)
    }

    func testRecoveryPackageValidationSucceeds() async throws {
        let service = DefaultRecoveryPackageService()
        let secret = RecoverySecret("correct horse battery staple")
        let package = try await makePackage(using: service, secret: secret)

        let result = await service.validateRecoveryPackage(package, recoverySecret: secret)

        XCTAssertEqual(result, .success)
    }

    func testRecoveryPackageValidationFailsForWrongSecret() async throws {
        let service = DefaultRecoveryPackageService()
        let package = try await makePackage(using: service)

        let result = await service.validateRecoveryPackage(
            package,
            recoverySecret: RecoverySecret("wrong secret")
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.failures, [.invalidValidationProof])
    }

    func testRecoveryPackageImportFailsForCorruptedPackage() async {
        let service = DefaultRecoveryPackageService()
        let corruptedData = Data("{not-json".utf8)

        await XCTAssertThrowsVaultError(.invalidInput("Recovery package JSON is invalid.")) {
            _ = try await service.importRecoveryPackage(from: corruptedData)
        }
    }

    func testRecoveryPackageValidationFailsForVersionMismatch() async throws {
        let service = DefaultRecoveryPackageService()
        var package = try await makePackage(using: service)
        package.formatVersion = DefaultRecoveryPackageService.supportedFormatVersion + 1

        let result = await service.validateRecoveryPackage(
            package,
            recoverySecret: RecoverySecret("correct horse battery staple")
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(.unsupportedFormatVersion))
    }

    func testRecoveryPackageExportDoesNotContainForbiddenSensitiveMaterial() async throws {
        let service = DefaultRecoveryPackageService()
        let secret = "correct horse battery staple"
        let package = try await makePackage(using: service, secret: RecoverySecret(secret))

        let exported = try await service.exportRecoveryPackage(package)
        let json = try XCTUnwrap(String(data: exported, encoding: .utf8))

        XCTAssertFalse(json.contains(secret))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("vaultKey"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("encryptionKey"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("payload"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("blob"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("recoverySecret"))
    }

    private func makePackage(
        using service: DefaultRecoveryPackageService,
        secret: RecoverySecret = RecoverySecret("correct horse battery staple")
    ) async throws -> RecoveryPackage {
        try await service.generateRecoveryPackage(
            vaultId: VaultID("vault-1"),
            deviceId: DeviceID("device-1"),
            recoverySecret: secret
        )
    }
}
