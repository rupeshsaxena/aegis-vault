import Foundation

public struct RealCryptoEngine: CryptoEngine {
    public init() {}

    public func generateKey() async throws -> SymmetricKeyMaterial {
        throw CryptoError.notImplemented
    }

    public func encrypt(_ plaintext: Data, using key: SymmetricKeyMaterial) async throws -> EncryptedEnvelope {
        throw CryptoError.notImplemented
    }

    public func decrypt(_ envelope: EncryptedEnvelope, using key: SymmetricKeyMaterial) async throws -> Data {
        throw CryptoError.notImplemented
    }

    public func wrapKey(_ key: SymmetricKeyMaterial, using wrappingKey: SymmetricKeyMaterial) async throws -> WrappedKey {
        throw CryptoError.notImplemented
    }

    public func unwrapKey(_ wrappedKey: WrappedKey, using wrappingKey: SymmetricKeyMaterial) async throws -> SymmetricKeyMaterial {
        throw CryptoError.notImplemented
    }
}
