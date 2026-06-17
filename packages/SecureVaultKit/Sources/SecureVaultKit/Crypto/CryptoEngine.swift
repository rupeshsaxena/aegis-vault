import Foundation

public protocol CryptoEngine: Sendable {
    func generateKey() async throws -> SymmetricKeyMaterial
    func encrypt(_ plaintext: Data, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope
    func decrypt(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> Data
    func wrapKey(_ key: SymmetricKeyMaterial, using wrappingKey: SymmetricKeyMaterial) async throws -> WrappedKey
    func unwrapKey(_ wrappedKey: WrappedKey, using wrappingKey: SymmetricKeyMaterial) async throws -> SymmetricKeyMaterial
}

extension CryptoEngine {
    internal func generateRootVaultKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-root-vault-key-\(vaultId.rawValue)")
    }

    internal func generateVaultEncryptionKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-vault-encryption-key-\(vaultId.rawValue)")
    }

    internal func generateItemKey(for objectId: VaultObjectID) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "fake-item-key-\(objectId.rawValue)")
    }

    internal func deriveVaultKey(for vaultId: VaultID, using method: UnlockMethod) async throws -> SymmetricKeyMaterial {
        SymmetricKeyMaterial(reference: "key-\(vaultId.rawValue)-\(method.fakeIdentifier)")
    }

    internal func wrapKey(_ key: SymmetricKeyMaterial, for deviceId: DeviceID) async throws -> WrappedKey {
        WrappedKey(
            keyReference: key.reference,
            wrappedByDeviceId: deviceId,
            wrappingKeyReference: "fake-device-wrapping-key-\(deviceId.rawValue)"
        )
    }

    internal func wrapItemKey(_ key: SymmetricKeyMaterial, usingVaultEncryptionKey keyReference: String) async throws -> WrappedKey {
        let wrappingKey = SymmetricKeyMaterial(reference: keyReference)
        return try await wrapKey(key, using: wrappingKey)
    }

    internal func unwrapItemKey(_ wrappedKey: WrappedKey, usingVaultEncryptionKey keyReference: String) async throws -> SymmetricKeyMaterial {
        let wrappingKey = SymmetricKeyMaterial(reference: keyReference)
        return try await unwrapKey(wrappedKey, using: wrappingKey)
    }

    internal func encryptMetadata(_ metadata: VaultMetadata, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let data = try JSONEncoder().encode(metadata)
        return try await encrypt(data, using: key)
    }

    internal func decryptMetadata(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> VaultMetadata {
        let data = try await decrypt(envelope, using: key)
        return try JSONDecoder().decode(VaultMetadata.self, from: data)
    }

    internal func encryptPayload(_ payload: VaultPayload, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        let data = try JSONEncoder().encode(payload)
        return try await encrypt(data, using: key)
    }

    internal func decryptPayload(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> VaultPayload {
        let data = try await decrypt(envelope, using: key)
        return try JSONDecoder().decode(VaultPayload.self, from: data)
    }
}
