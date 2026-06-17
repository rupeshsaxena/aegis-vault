import CryptoKit
import Foundation

public struct RealCryptoEngine: CryptoEngine {
    private static let envelopeVersion = 1
    private static let keyByteCount = 32
    private static let nonceByteCount = 12
    private static let authenticationTagByteCount = 16

    public init() {}

    public func generateKey() async throws -> SymmetricKeyMaterial {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { buffer in
            Data(buffer)
        }
        return SymmetricKeyMaterial(
            keyId: KeyIdentifier("key-\(UUID().uuidString)"),
            data: keyData
        )
    }

    public func encrypt(_ plaintext: Data, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let symmetricKey = try cryptoKitKey(from: key)
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: nonce)
        return EncryptedEnvelope(
            version: Self.envelopeVersion,
            algorithm: .aesGCM,
            keyId: key.keyId,
            nonce: Data(nonce),
            ciphertext: sealedBox.ciphertext + sealedBox.tag
        )
    }

    public func decrypt(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> Data {
        guard envelope.version == Self.envelopeVersion,
              envelope.algorithm == .aesGCM,
              envelope.keyId == key.keyId,
              envelope.nonce.count == Self.nonceByteCount,
              envelope.ciphertext.count >= Self.authenticationTagByteCount else {
            throw CryptoError.invalidEnvelope
        }

        let symmetricKey = try cryptoKitKey(from: key)
        let ciphertext = envelope.ciphertext.dropLast(Self.authenticationTagByteCount)
        let tag = envelope.ciphertext.suffix(Self.authenticationTagByteCount)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: envelope.nonce),
            ciphertext: ciphertext,
            tag: tag
        )
        do {
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw CryptoError.invalidEnvelope
        }
    }

    public func wrapKey(_ key: SymmetricKeyMaterial, using wrappingKey: SymmetricKeyMaterial) async throws -> WrappedKey {
        let envelope = try await encrypt(key.data, using: wrappingKey)
        return WrappedKey(
            keyId: key.keyId,
            wrappingKeyId: wrappingKey.keyId,
            wrappedData: envelope.nonce + envelope.ciphertext,
            algorithm: .aesGCM
        )
    }

    public func unwrapKey(_ wrappedKey: WrappedKey, using wrappingKey: SymmetricKeyMaterial) async throws -> SymmetricKeyMaterial {
        guard wrappedKey.algorithm == .aesGCM,
              wrappedKey.wrappingKeyId == wrappingKey.keyId,
              wrappedKey.wrappedData.count > Self.nonceByteCount + Self.authenticationTagByteCount else {
            throw CryptoError.invalidWrappedKey
        }

        let nonce = wrappedKey.wrappedData.prefix(Self.nonceByteCount)
        let ciphertext = wrappedKey.wrappedData.dropFirst(Self.nonceByteCount)
        let envelope = EncryptedEnvelope(
            version: Self.envelopeVersion,
            algorithm: .aesGCM,
            keyId: wrappingKey.keyId,
            nonce: nonce,
            ciphertext: ciphertext
        )
        do {
            let keyData = try await decrypt(envelope, using: wrappingKey)
            return SymmetricKeyMaterial(keyId: wrappedKey.keyId, data: keyData)
        } catch {
            throw CryptoError.invalidWrappedKey
        }
    }

    private func cryptoKitKey(from key: SymmetricKeyMaterial) throws -> SymmetricKey {
        guard key.data.count == Self.keyByteCount else {
            throw CryptoError.invalidKeyMaterial
        }
        return SymmetricKey(data: key.data)
    }
}
