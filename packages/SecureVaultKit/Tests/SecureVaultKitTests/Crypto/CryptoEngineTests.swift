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

    func testRealCryptoGenerateKeyReturnsUniqueKeys() async throws {
        let crypto = RealCryptoEngine()

        let firstKey = try await crypto.generateKey()
        let secondKey = try await crypto.generateKey()

        XCTAssertNotEqual(firstKey.keyId, secondKey.keyId)
        XCTAssertNotEqual(firstKey.data, secondKey.data)
        XCTAssertEqual(firstKey.data.count, 32)
        XCTAssertEqual(secondKey.data.count, 32)
    }

    func testRealCryptoEncryptDecryptRoundTrip() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()
        let plaintext = Data("real encrypted payload".utf8)

        let envelope = try await crypto.encrypt(plaintext, using: key)
        let decrypted = try await crypto.decrypt(envelope, using: key)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertNotEqual(envelope.ciphertext, plaintext)
    }

    func testRealCryptoDecryptWithWrongKeyFails() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()
        let wrongKey = try await crypto.generateKey()
        let envelope = try await crypto.encrypt(Data("secret".utf8), using: key)

        do {
            _ = try await crypto.decrypt(envelope, using: wrongKey)
            XCTFail("Expected decrypt with wrong key to fail.")
        } catch let error as CryptoError {
            XCTAssertEqual(error, .invalidEnvelope)
        }
    }

    func testRealCryptoTamperedCiphertextFails() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()
        var envelope = try await crypto.encrypt(Data("secret".utf8), using: key)
        let firstCiphertextIndex = envelope.ciphertext.startIndex
        envelope.ciphertext[firstCiphertextIndex] ^= 0xff

        do {
            _ = try await crypto.decrypt(envelope, using: key)
            XCTFail("Expected tampered ciphertext to fail.")
        } catch let error as CryptoError {
            XCTAssertEqual(error, .invalidEnvelope)
        }
    }

    func testRealCryptoWrapUnwrapRoundTrip() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()
        let wrappingKey = try await crypto.generateKey()

        let wrappedKey = try await crypto.wrapKey(key, using: wrappingKey)
        let unwrappedKey = try await crypto.unwrapKey(wrappedKey, using: wrappingKey)

        XCTAssertEqual(unwrappedKey, key)
        XCTAssertNotEqual(wrappedKey.wrappedData, key.data)
    }

    func testRealCryptoUnwrapWithWrongKeyFails() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()
        let wrappingKey = try await crypto.generateKey()
        let wrongWrappingKey = try await crypto.generateKey()
        let wrappedKey = try await crypto.wrapKey(key, using: wrappingKey)

        do {
            _ = try await crypto.unwrapKey(wrappedKey, using: wrongWrappingKey)
            XCTFail("Expected unwrap with wrong key to fail.")
        } catch let error as CryptoError {
            XCTAssertEqual(error, .invalidWrappedKey)
        }
    }

    func testEncryptedEnvelopeContainsAlgorithmAndVersion() async throws {
        let crypto = RealCryptoEngine()
        let key = try await crypto.generateKey()

        let envelope = try await crypto.encrypt(Data("secret".utf8), using: key)

        XCTAssertEqual(envelope.version, 1)
        XCTAssertEqual(envelope.algorithm, .aesGCM)
        XCTAssertEqual(envelope.keyId, key.keyId)
        XCTAssertFalse(envelope.nonce.isEmpty)
        XCTAssertFalse(envelope.ciphertext.isEmpty)
    }
}
