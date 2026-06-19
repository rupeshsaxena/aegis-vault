import Foundation

public actor InMemorySecureKeyStore: SecureKeyStore {
    private struct StoredItem: Sendable {
        var key: SymmetricKeyMaterial
        var metadata: SecureKeyStoreItemMetadata
    }

    private var items: [SecureKeyStoreKey: StoredItem] = [:]
    private var operationToFail: SecureKeyStoreOperation?

    public init() {}

    public func storeKey(
        _ key: SymmetricKeyMaterial,
        for identifier: SecureKeyStoreKey,
        accessPolicy: SecureKeyStoreAccessPolicy
    ) throws {
        try consumeInjectedFailure(for: .store)

        let now = Date()
        let createdAt = items[identifier]?.metadata.createdAt ?? now
        let metadata = SecureKeyStoreItemMetadata(
            identifier: identifier,
            createdAt: createdAt,
            updatedAt: now,
            accessPolicy: accessPolicy,
            keyId: key.keyId
        )
        items[identifier] = StoredItem(key: key, metadata: metadata)
    }

    public func loadKey(for identifier: SecureKeyStoreKey) throws -> SymmetricKeyMaterial {
        try consumeInjectedFailure(for: .load)
        guard let item = items[identifier] else {
            throw SecureKeyStoreError.keyNotFound(identifier)
        }
        return item.key
    }

    public func deleteKey(for identifier: SecureKeyStoreKey) throws {
        try consumeInjectedFailure(for: .delete)
        guard items.removeValue(forKey: identifier) != nil else {
            throw SecureKeyStoreError.keyNotFound(identifier)
        }
    }

    public func containsKey(for identifier: SecureKeyStoreKey) throws -> Bool {
        try consumeInjectedFailure(for: .contains)
        return items[identifier] != nil
    }

    public func listKeys() throws -> [SecureKeyStoreItemMetadata] {
        try consumeInjectedFailure(for: .list)
        return items.values
            .map(\.metadata)
            .sorted { $0.identifier.rawValue < $1.identifier.rawValue }
    }

    public func failNextOperation(_ operation: SecureKeyStoreOperation) {
        operationToFail = operation
    }

    private func consumeInjectedFailure(for operation: SecureKeyStoreOperation) throws {
        guard operationToFail == operation else {
            return
        }
        operationToFail = nil
        throw SecureKeyStoreError.injectedFailure(operation)
    }
}
