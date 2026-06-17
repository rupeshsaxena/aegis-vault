import Foundation

public actor FakeCryptoEngine: CryptoEngine {
    private var keyCounter = 0

    public init() {}

    public func generateKey() async throws -> SymmetricKeyMaterial {
        keyCounter += 1
        let keyId = KeyIdentifier("fake-key-\(keyCounter)")
        return SymmetricKeyMaterial(
            keyId: keyId,
            data: Data("fake-key-material-\(keyCounter)".utf8)
        )
    }

    public func encrypt(_ plaintext: Data, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let encodedPlaintext = plaintext.base64EncodedString()
        let ciphertext = Data("fake-ciphertext:\(encodedPlaintext)".utf8)
        return EncryptedEnvelope(
            version: 1,
            algorithm: .xChaCha20Poly1305,
            keyId: key.keyId,
            nonce: Data("fake-nonce-\(key.keyId.rawValue)".utf8),
            ciphertext: ciphertext
        )
    }

    public func decrypt(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> Data {
        guard envelope.keyId == key.keyId,
              let ciphertext = String(data: envelope.ciphertext, encoding: .utf8),
              ciphertext.hasPrefix("fake-ciphertext:") else {
            throw CryptoError.invalidEnvelope
        }
        let encodedPlaintext = String(ciphertext.dropFirst("fake-ciphertext:".count))
        guard let plaintext = Data(base64Encoded: encodedPlaintext) else {
            throw CryptoError.invalidEnvelope
        }
        return plaintext
    }

    public func wrapKey(_ key: SymmetricKeyMaterial, using wrappingKey: SymmetricKeyMaterial) async throws -> WrappedKey {
        let encodedKeyMaterial = key.data.base64EncodedString()
        return WrappedKey(
            keyId: key.keyId,
            wrappingKeyId: wrappingKey.keyId,
            wrappedData: Data("fake-wrapped-key:\(encodedKeyMaterial)".utf8),
            algorithm: .xChaCha20Poly1305
        )
    }

    public func unwrapKey(_ wrappedKey: WrappedKey, using wrappingKey: SymmetricKeyMaterial) async throws -> SymmetricKeyMaterial {
        guard wrappedKey.wrappingKeyId == wrappingKey.keyId,
              let wrappedData = String(data: wrappedKey.wrappedData, encoding: .utf8),
              wrappedData.hasPrefix("fake-wrapped-key:") else {
            throw CryptoError.invalidWrappedKey
        }
        let encodedKeyMaterial = String(wrappedData.dropFirst("fake-wrapped-key:".count))
        guard let keyMaterial = Data(base64Encoded: encodedKeyMaterial) else {
            throw CryptoError.invalidWrappedKey
        }
        return SymmetricKeyMaterial(keyId: wrappedKey.keyId, data: keyMaterial)
    }
}
