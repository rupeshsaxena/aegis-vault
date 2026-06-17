import Foundation
import XCTest
@testable import SecureVaultKit

final class CryptoEngineTests: XCTestCase {
    func testKeyIdentifierStoresRawValue() {
        let keyId = KeyIdentifier("key-1")

        XCTAssertEqual(keyId.rawValue, "key-1")
        XCTAssertEqual(keyId.description, "key-1")
    }

    func testSymmetricKeyMaterialCreation() {
        let key = SymmetricKeyMaterial(
            keyId: KeyIdentifier("key-1"),
            data: Data([1, 2, 3])
        )

        XCTAssertEqual(key.keyId, KeyIdentifier("key-1"))
        XCTAssertEqual(key.data, Data([1, 2, 3]))
    }

    func testWrappedKeyCreation() {
        let wrappedKey = WrappedKey(
            keyId: KeyIdentifier("data-key"),
            wrappingKeyId: KeyIdentifier("wrapping-key"),
            wrappedData: Data([4, 5, 6]),
            algorithm: .xChaCha20Poly1305
        )

        XCTAssertEqual(wrappedKey.keyId, KeyIdentifier("data-key"))
        XCTAssertEqual(wrappedKey.wrappingKeyId, KeyIdentifier("wrapping-key"))
        XCTAssertEqual(wrappedKey.wrappedData, Data([4, 5, 6]))
        XCTAssertEqual(wrappedKey.algorithm, .xChaCha20Poly1305)
    }

    func testEncryptedEnvelopeCodableRoundTrip() throws {
        let envelope = EncryptedEnvelope(
            version: 1,
            algorithm: .xChaCha20Poly1305,
            keyId: KeyIdentifier("key-1"),
            nonce: Data([1, 2, 3]),
            ciphertext: Data([4, 5, 6])
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(EncryptedEnvelope.self, from: encoded)

        XCTAssertEqual(decoded, envelope)
    }

    func testFakeCryptoGenerateKey() async throws {
        let crypto = FakeCryptoEngine()

        let key = try await crypto.generateKey()

        XCTAssertFalse(key.keyId.rawValue.isEmpty)
        XCTAssertFalse(key.data.isEmpty)
    }

    func testFakeCryptoEncryptDecryptRoundTrip() async throws {
        let crypto = FakeCryptoEngine()
        let key = try await crypto.generateKey()
        let plaintext = Data("hello vault".utf8)

        let envelope = try await crypto.encrypt(plaintext, using: key)
        let decrypted = try await crypto.decrypt(envelope, using: key)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertEqual(envelope.algorithm, .xChaCha20Poly1305)
        XCTAssertEqual(envelope.keyId, key.keyId)
    }

    func testFakeCryptoWrapUnwrapRoundTrip() async throws {
        let crypto = FakeCryptoEngine()
        let key = try await crypto.generateKey()
        let wrappingKey = try await crypto.generateKey()

        let wrappedKey = try await crypto.wrapKey(key, using: wrappingKey)
        let unwrappedKey = try await crypto.unwrapKey(wrappedKey, using: wrappingKey)

        XCTAssertEqual(unwrappedKey, key)
        XCTAssertEqual(wrappedKey.algorithm, .xChaCha20Poly1305)
        XCTAssertEqual(wrappedKey.keyId, key.keyId)
        XCTAssertEqual(wrappedKey.wrappingKeyId, wrappingKey.keyId)
    }

    func testRealCryptoEngineThrowsNotImplemented() async {
        let crypto = RealCryptoEngine()

        do {
            _ = try await crypto.generateKey()
            XCTFail("Expected RealCryptoEngine.generateKey to throw.")
        } catch let error as CryptoError {
            XCTAssertEqual(error, .notImplemented)
        } catch {
            XCTFail("Expected CryptoError.notImplemented, got \(error).")
        }
    }
}
