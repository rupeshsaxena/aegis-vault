import Foundation
import XCTest
@testable import SecureVaultKit

final class BiometricUnlockTests: XCTestCase {
    func testBiometricUnlockSucceedsWhenProviderSucceeds() async throws {
        let engine = try await makeLockedEngine(
            provider: FakeBiometricAuthProvider(behavior: .result(.success))
        )

        try await engine.unlockVault(method: .biometric)

        let state = await engine.sessionActor.currentState()
        XCTAssertEqual(state, .unlocked)
    }

    func testBiometricUnlockFailsWhenProviderUnavailable() async throws {
        let engine = try await makeLockedEngine(
            provider: FakeBiometricAuthProvider(available: false)
        )

        await XCTAssertThrowsVaultError(.biometricUnavailable) {
            try await engine.unlockVault(method: .biometric)
        }
        let state = await engine.sessionActor.currentState()
        XCTAssertEqual(state, .locked)
    }

    func testBiometricUnlockFailsWhenProviderCancels() async throws {
        let engine = try await makeLockedEngine(
            provider: FakeBiometricAuthProvider(behavior: .result(.cancelled))
        )

        await XCTAssertThrowsVaultError(.authenticationCancelled) {
            try await engine.unlockVault(method: .biometric)
        }
    }

    func testBiometricUnlockFailsWhenProviderFails() async throws {
        let engine = try await makeLockedEngine(
            provider: FakeBiometricAuthProvider(behavior: .result(.failed))
        )

        await XCTAssertThrowsVaultError(.authenticationFailed) {
            try await engine.unlockVault(method: .biometric)
        }
    }

    func testBiometricUnlockMapsLockedOutError() async throws {
        let engine = try await makeLockedEngine(
            provider: FakeBiometricAuthProvider(behavior: .error(.lockedOut))
        )

        await XCTAssertThrowsVaultError(.biometricLockedOut) {
            try await engine.unlockVault(method: .biometric)
        }
    }

    func testBiometricProviderNotConfiguredReturnsUnavailable() async throws {
        let engine = try await makeLockedEngine(provider: nil)

        await XCTAssertThrowsVaultError(.biometricUnavailable) {
            try await engine.unlockVault(method: .biometric)
        }
    }

    func testBiometricProviderDoesNotExposeRawKeyTypes() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceRoot = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SecureVaultKit/Infrastructure")
        let providerSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("BiometricAuthProvider.swift"),
            encoding: .utf8
        )
        let localSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("LocalBiometricAuthProvider.swift"),
            encoding: .utf8
        )
        let combined = providerSource + localSource

        XCTAssertFalse(combined.contains("SymmetricKeyMaterial"))
        XCTAssertFalse(combined.contains("VaultSession"))
        XCTAssertFalse(combined.contains("CryptoEngine"))
        XCTAssertFalse(combined.contains("keyReference"))
    }

    private func makeLockedEngine(
        provider: (any BiometricAuthProvider)?
    ) async throws -> DefaultVaultEngine {
        let configuration = makeInMemoryConfiguration(
            biometricAuthProvider: provider
        )
        let engine = DefaultVaultEngine(configuration: configuration)
        let vaultID = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )
        await engine.lockVault(id: vaultID)
        return engine
    }
}
