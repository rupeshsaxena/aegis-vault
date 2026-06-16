import Foundation

public struct EncryptedPayload: Equatable, Sendable {
    public var ciphertext: Data
    public var nonce: Data
    public var algorithm: String

    public init(ciphertext: Data, nonce: Data, algorithm: String) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.algorithm = algorithm
    }
}

public protocol VaultCryptoProvider: Sendable {
    func encrypt(_ plaintext: Data, context: String) async throws -> EncryptedPayload
    func decrypt(_ payload: EncryptedPayload, context: String) async throws -> Data
}

public enum UnlockMethod: String, CaseIterable, Codable, Sendable {
    case biometric
    case passkey
    case recoveryPackage
}

public struct UnlockRequest: Equatable, Sendable {
    public var vaultID: VaultID
    public var method: UnlockMethod
    public var reason: String

    public init(vaultID: VaultID, method: UnlockMethod, reason: String) {
        self.vaultID = vaultID
        self.method = method
        self.reason = reason
    }
}

public protocol VaultUnlocking: Sendable {
    func unlock(_ request: UnlockRequest) async throws -> Bool
    func lock(vaultID: VaultID) async
    func isUnlocked(vaultID: VaultID) async -> Bool
}
