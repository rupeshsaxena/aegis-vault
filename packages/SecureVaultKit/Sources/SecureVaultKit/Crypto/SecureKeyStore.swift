import Foundation

public struct SecureKeyStoreKey: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum SecureKeyStoreAccessPolicy: String, Codable, Hashable, Sendable {
    case afterFirstUnlock
    case whenUnlocked
    case biometricCurrentSet
    case passcodeProtected
}

public struct SecureKeyStoreItemMetadata: Equatable, Codable, Sendable {
    public var identifier: SecureKeyStoreKey
    public var createdAt: Date
    public var updatedAt: Date
    public var accessPolicy: SecureKeyStoreAccessPolicy
    public var keyId: KeyIdentifier

    public init(
        identifier: SecureKeyStoreKey,
        createdAt: Date,
        updatedAt: Date,
        accessPolicy: SecureKeyStoreAccessPolicy,
        keyId: KeyIdentifier
    ) {
        self.identifier = identifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.accessPolicy = accessPolicy
        self.keyId = keyId
    }
}

public enum SecureKeyStoreOperation: String, Equatable, Codable, Sendable {
    case store
    case load
    case delete
    case contains
    case list
}

public enum SecureKeyStoreError: Error, Equatable, Sendable {
    case notImplemented
    case keyNotFound(SecureKeyStoreKey)
    case injectedFailure(SecureKeyStoreOperation)
    case invalidIdentifier
    case invalidStoredItem
    case authenticationFailed
    case platformError(Int32)
}

public protocol SecureKeyStore: Sendable {
    func storeKey(
        _ key: SymmetricKeyMaterial,
        for identifier: SecureKeyStoreKey,
        accessPolicy: SecureKeyStoreAccessPolicy
    ) async throws

    func loadKey(for identifier: SecureKeyStoreKey) async throws -> SymmetricKeyMaterial
    func deleteKey(for identifier: SecureKeyStoreKey) async throws
    func containsKey(for identifier: SecureKeyStoreKey) async throws -> Bool
    func listKeys() async throws -> [SecureKeyStoreItemMetadata]
}
