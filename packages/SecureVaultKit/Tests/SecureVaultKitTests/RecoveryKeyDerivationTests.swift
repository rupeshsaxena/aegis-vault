import Foundation
import XCTest
@testable import SecureVaultKit

final class RecoveryKeyDerivationTests: XCTestCase {
    func testRecoverySecretNormalizationTrimsWhitespace() {
        let secret = RecoverySecret("  correct horse battery staple\n")

        XCTAssertEqual(secret.normalizedForDerivation, "correct horse battery staple")
    }

    func testRecoverySecretNormalizationCollapsesRepeatedSpaces() {
        let secret = RecoverySecret("correct   horse\tbattery\n\nstaple")

        XCTAssertEqual(secret.normalizedForDerivation, "correct horse battery staple")
    }

    func testFakeDerivationSameInputSameSaltSameOutput() async throws {
        let engine = FakeKeyDerivationEngine()
        let parameters = makeParameters(salt: Data("salt-1".utf8))

        let first = try await engine.deriveKey(
            from: RecoverySecret("correct horse battery staple"),
            parameters: parameters
        )
        let second = try await engine.deriveKey(
            from: RecoverySecret("  correct   horse battery staple  "),
            parameters: parameters
        )

        XCTAssertEqual(first.data, second.data)
        XCTAssertEqual(first.keyId, second.keyId)
    }

    func testFakeDerivationDifferentSaltDifferentOutput() async throws {
        let engine = FakeKeyDerivationEngine()
        let secret = RecoverySecret("correct horse battery staple")

        let first = try await engine.deriveKey(
            from: secret,
            parameters: makeParameters(salt: Data("salt-1".utf8))
        )
        let second = try await engine.deriveKey(
            from: secret,
            parameters: makeParameters(salt: Data("salt-2".utf8))
        )

        XCTAssertNotEqual(first.data, second.data)
        XCTAssertNotEqual(first.keyId, second.keyId)
    }

    func testDerivedKeyMaterialContainsParameters() async throws {
        let engine = FakeKeyDerivationEngine()
        let parameters = makeParameters(salt: Data("salt-1".utf8), outputLength: 48)

        let derivedKey = try await engine.deriveKey(
            from: RecoverySecret("correct horse battery staple"),
            parameters: parameters
        )

        XCTAssertEqual(derivedKey.parameters, parameters)
        XCTAssertEqual(derivedKey.data.count, 48)
        XCTAssertFalse(derivedKey.keyId.rawValue.isEmpty)
    }

    func testRealDerivationThrowsNotImplementedIfNoApprovedDependency() async {
        let engine = RealKeyDerivationEngine()

        do {
            _ = try await engine.deriveKey(
                from: RecoverySecret("correct horse battery staple"),
                parameters: makeParameters(salt: Data("salt-1".utf8))
            )
            XCTFail("Expected real key derivation to throw until Argon2id is approved.")
        } catch let error as CryptoError {
            XCTAssertEqual(error, .notImplemented)
        } catch {
            XCTFail("Expected CryptoError.notImplemented, got \(error).")
        }
    }

    func testRawRecoverySecretIsNotStoredInRecoveryPackage() async throws {
        let service = DefaultRecoveryPackageService()
        let rawSecret = "  correct   horse battery staple  "
        let package = try await service.generateRecoveryPackage(
            vaultId: VaultID("vault-1"),
            deviceId: DeviceID("device-1"),
            recoverySecret: RecoverySecret(rawSecret)
        )

        let exported = try await service.exportRecoveryPackage(package)
        let json = try XCTUnwrap(String(data: exported, encoding: .utf8))

        XCTAssertFalse(json.contains(rawSecret))
        XCTAssertFalse(json.contains("correct horse battery staple"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("recoverySecret"))
    }

    private func makeParameters(
        salt: Data,
        outputLength: Int = 32
    ) -> KeyDerivationParameters {
        KeyDerivationParameters(
            memoryCost: 64 * 1024,
            iterations: 3,
            parallelism: 1,
            salt: salt,
            outputLength: outputLength
        )
    }
}
