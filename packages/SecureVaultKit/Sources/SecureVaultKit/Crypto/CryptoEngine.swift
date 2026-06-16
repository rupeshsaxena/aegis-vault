internal protocol CryptoEngine: Sendable {
    func generateRootVaultKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial
    func generateVaultEncryptionKey(for vaultId: VaultID) async throws -> SymmetricKeyMaterial
    func generateItemKey(for objectId: VaultObjectID) async throws -> SymmetricKeyMaterial
    func deriveVaultKey(for vaultId: VaultID, using method: UnlockMethod) async throws -> SymmetricKeyMaterial
    func wrapKey(_ key: SymmetricKeyMaterial, for deviceId: DeviceID) async throws -> WrappedKey
    func wrapItemKey(_ key: SymmetricKeyMaterial, usingVaultEncryptionKey keyReference: String) async throws -> WrappedKey
    func encryptMetadata(_ metadata: VaultMetadata, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope
    func encryptPayload(_ payload: VaultPayload, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope
    func decryptPayload(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> VaultPayload
}
