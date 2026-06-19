import Foundation
import XCTest
@testable import SecureVaultKit

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

#if os(iOS) || os(macOS)
    func testKeychainSecureKeyStoreThrowsNotImplementedForNow() async {
        let store = KeychainSecureKeyStore()

        do {
            _ = try await store.listKeys()
            XCTFail("Expected the Keychain skeleton to be unimplemented.")
        } catch let error as SecureKeyStoreError {
            XCTAssertEqual(error, .notImplemented)
        } catch {
            XCTFail("Expected SecureKeyStoreError, got \(error).")
        }
    }
#endif

    private func makeKey(id: KeyIdentifier = "test-key-v1") -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(keyId: id, data: Data(repeating: 7, count: 32))
    }
}
