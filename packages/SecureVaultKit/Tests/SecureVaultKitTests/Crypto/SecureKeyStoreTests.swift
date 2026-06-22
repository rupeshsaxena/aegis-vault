import Foundation
import XCTest
@testable import SecureVaultKit
#if canImport(Security)
import Security
#endif

final class SecureKeyStoreTests: XCTestCase {
    func testStoreKeyThenContainsReturnsTrue() async throws {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("vault-encryption-key")

        try await store.storeKey(makeKey(), for: identifier, accessPolicy: .whenUnlocked)

        let containsKey = try await store.containsKey(for: identifier)
        XCTAssertTrue(containsKey)
    }

    func testLoadKeyReturnsStoredKey() async throws {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("root-vault-key")
        let key = makeKey(id: "rvk-v1")
        try await store.storeKey(key, for: identifier, accessPolicy: .passcodeProtected)

        let loadedKey = try await store.loadKey(for: identifier)

        XCTAssertEqual(loadedKey, key)
    }

    func testDeleteKeyRemovesKey() async throws {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("vault-encryption-key")
        try await store.storeKey(makeKey(), for: identifier, accessPolicy: .afterFirstUnlock)

        try await store.deleteKey(for: identifier)

        let containsKey = try await store.containsKey(for: identifier)
        XCTAssertFalse(containsKey)
    }

    func testListKeysReturnsMetadata() async throws {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("vault-encryption-key")
        let key = makeKey(id: "vek-v2")
        try await store.storeKey(key, for: identifier, accessPolicy: .biometricCurrentSet)

        let metadata = try await store.listKeys()

        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata.first?.identifier, identifier)
        XCTAssertEqual(metadata.first?.accessPolicy, .biometricCurrentSet)
        XCTAssertEqual(metadata.first?.keyId, key.keyId)
    }

    func testInMemoryAccessPolicyMetadataIsPreserved() async throws {
        let store = InMemorySecureKeyStore()
        let policies: [SecureKeyStoreAccessPolicy] = [
            .afterFirstUnlock,
            .whenUnlocked,
            .biometricCurrentSet,
            .passcodeProtected
        ]

        for policy in policies {
            try await store.storeKey(
                makeKey(id: KeyIdentifier("key-\(policy.rawValue)")),
                for: SecureKeyStoreKey(policy.rawValue),
                accessPolicy: policy
            )
        }

        let metadata = try await store.listKeys()
        XCTAssertEqual(Set(metadata.map(\.accessPolicy)), Set(policies))
    }

    func testLoadMissingKeyThrows() async {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("missing-key")

        do {
            _ = try await store.loadKey(for: identifier)
            XCTFail("Expected a missing-key error.")
        } catch let error as SecureKeyStoreError {
            XCTAssertEqual(error, .keyNotFound(identifier))
        } catch {
            XCTFail("Expected SecureKeyStoreError, got \(error).")
        }
    }

    func testInMemoryStoreFailureInjectionWorks() async throws {
        let store = InMemorySecureKeyStore()
        let identifier = SecureKeyStoreKey("vault-encryption-key")
        await store.failNextOperation(.store)

        do {
            try await store.storeKey(makeKey(), for: identifier, accessPolicy: .whenUnlocked)
            XCTFail("Expected an injected store failure.")
        } catch let error as SecureKeyStoreError {
            XCTAssertEqual(error, .injectedFailure(.store))
        }
        let containsKey = try await store.containsKey(for: identifier)
        XCTAssertFalse(containsKey)
    }

#if canImport(Security)
    func testKeychainStoreLoadRoundTrip() async throws {
        let store = KeychainSecureKeyStore()
        let identifier = uniqueIdentifier()
        let key = makeKey(id: "keychain-roundtrip")
        try? await store.deleteKey(for: identifier)

        do {
            try await store.storeKey(key, for: identifier, accessPolicy: .whenUnlocked)
            let loaded = try await store.loadKey(for: identifier)
            XCTAssertEqual(loaded, key)
            try await store.deleteKey(for: identifier)
        } catch {
            try? await store.deleteKey(for: identifier)
            try skipIfKeychainUnavailable(error)
            throw error
        }
    }

    func testKeychainContainsAfterStore() async throws {
        let store = KeychainSecureKeyStore()
        let identifier = uniqueIdentifier()
        try? await store.deleteKey(for: identifier)

        do {
            try await store.storeKey(makeKey(), for: identifier, accessPolicy: .afterFirstUnlock)
            let containsKey = try await store.containsKey(for: identifier)
            XCTAssertTrue(containsKey)
            let metadata = try await store.listKeys()
            XCTAssertEqual(metadata.first { $0.identifier == identifier }?.accessPolicy, .afterFirstUnlock)
            try await store.deleteKey(for: identifier)
        } catch {
            try? await store.deleteKey(for: identifier)
            try skipIfKeychainUnavailable(error)
            throw error
        }
    }

    func testKeychainDeleteRemovesKey() async throws {
        let store = KeychainSecureKeyStore()
        let identifier = uniqueIdentifier()
        try? await store.deleteKey(for: identifier)

        do {
            try await store.storeKey(makeKey(), for: identifier, accessPolicy: .whenUnlocked)
            try await store.deleteKey(for: identifier)
            let containsKey = try await store.containsKey(for: identifier)
            XCTAssertFalse(containsKey)
        } catch {
            try? await store.deleteKey(for: identifier)
            try skipIfKeychainUnavailable(error)
            throw error
        }
    }
#endif

    func testKeyStoreSourceDoesNotUseUserDefaultsOrLogging() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SecureVaultKit/Crypto/KeychainSecureKeyStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("UserDefaults"))
        XCTAssertFalse(source.contains("print("))
        XCTAssertFalse(source.contains("debugPrint("))
        XCTAssertFalse(source.contains("Logger"))
        XCTAssertFalse(source.contains("os_log"))
    }

    func testViewModelsDoNotAccessSecureKeyStore() throws {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presentationURL = repositoryRoot.appendingPathComponent("ios/AegisVault/Presentation")
        let enumerator = FileManager.default.enumerator(
            at: presentationURL,
            includingPropertiesForKeys: nil
        )
        let swiftFiles = (enumerator?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "swift" }
        let source = try swiftFiles
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertFalse(source.contains("SecureKeyStore"))
        XCTAssertFalse(source.contains("KeychainSecureKeyStore"))
        XCTAssertFalse(source.contains("import Security"))
        XCTAssertFalse(source.contains("import LocalAuthentication"))
    }

    private func makeKey(id: KeyIdentifier = "test-key-v1") -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(keyId: id, data: Data(repeating: 7, count: 32))
    }

#if canImport(Security)
    private func uniqueIdentifier() -> SecureKeyStoreKey {
        SecureKeyStoreKey("tests.\(UUID().uuidString)")
    }

    private func skipIfKeychainUnavailable(_ error: Error) throws {
        guard case SecureKeyStoreError.platformError(let status) = error,
              [errSecNotAvailable, errSecInteractionNotAllowed, errSecMissingEntitlement].contains(status) else {
            return
        }
        throw XCTSkip("Keychain is unavailable in this test environment (OSStatus \(status)).")
    }
#endif
}
