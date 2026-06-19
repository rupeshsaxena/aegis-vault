#if os(iOS) || os(macOS)
public struct KeychainSecureKeyStore: SecureKeyStore {
    public init() {}

    public func storeKey(
        _ key: SymmetricKeyMaterial,
        for identifier: SecureKeyStoreKey,
        accessPolicy: SecureKeyStoreAccessPolicy
    ) async throws {
        _ = key
        _ = identifier
        _ = accessPolicy
        throw SecureKeyStoreError.notImplemented
    }

    public func loadKey(for identifier: SecureKeyStoreKey) async throws -> SymmetricKeyMaterial {
        _ = identifier
        throw SecureKeyStoreError.notImplemented
    }

    public func deleteKey(for identifier: SecureKeyStoreKey) async throws {
        _ = identifier
        throw SecureKeyStoreError.notImplemented
    }

    public func containsKey(for identifier: SecureKeyStoreKey) async throws -> Bool {
        _ = identifier
        throw SecureKeyStoreError.notImplemented
    }

    public func listKeys() async throws -> [SecureKeyStoreItemMetadata] {
        throw SecureKeyStoreError.notImplemented
    }
}
#endif
