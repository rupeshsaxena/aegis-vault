#if canImport(Security)
import Foundation
import LocalAuthentication
import Security

public actor KeychainSecureKeyStore: SecureKeyStore {
    internal static let service = "com.aegisvault.securevaultkit.keys"

    private struct StoredMetadata: Codable {
        let keyId: KeyIdentifier
        let createdAt: Date
        let updatedAt: Date
        let accessPolicy: SecureKeyStoreAccessPolicy

        func publicValue(identifier: SecureKeyStoreKey) -> SecureKeyStoreItemMetadata {
            SecureKeyStoreItemMetadata(
                identifier: identifier,
                createdAt: createdAt,
                updatedAt: updatedAt,
                accessPolicy: accessPolicy,
                keyId: keyId
            )
        }
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func storeKey(
        _ key: SymmetricKeyMaterial,
        for identifier: SecureKeyStoreKey,
        accessPolicy: SecureKeyStoreAccessPolicy
    ) throws {
        try validate(identifier)
        let existingMetadata = try metadata(for: identifier)
        let now = Date()
        let metadata = StoredMetadata(
            keyId: key.keyId,
            createdAt: existingMetadata?.createdAt ?? now,
            updatedAt: now,
            accessPolicy: accessPolicy
        )
        let values: [String: Any] = [
            kSecValueData as String: key.data,
            kSecAttrGeneric as String: try encoder.encode(metadata)
        ]

        if let existingMetadata {
            if existingMetadata.accessPolicy == accessPolicy {
                try check(
                    SecItemUpdate(baseQuery(for: identifier) as CFDictionary, values as CFDictionary),
                    identifier: identifier
                )
                return
            }
            try deleteItemIfPresent(identifier)
        }

        var item = baseQuery(for: identifier)
        values.forEach { item[$0.key] = $0.value }
        try accessAttributes(for: accessPolicy).forEach { item[$0.key] = $0.value }
        try check(SecItemAdd(item as CFDictionary, nil), identifier: identifier)
    }

    public func loadKey(for identifier: SecureKeyStoreKey) throws -> SymmetricKeyMaterial {
        try validate(identifier)
        var query = baseQuery(for: identifier)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = LAContext()

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        try check(status, identifier: identifier)
        guard let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data,
              let metadata = try decodeMetadata(from: attributes) else {
            throw SecureKeyStoreError.invalidStoredItem
        }
        return SymmetricKeyMaterial(keyId: metadata.keyId, data: data)
    }

    public func deleteKey(for identifier: SecureKeyStoreKey) throws {
        try validate(identifier)
        let status = SecItemDelete(baseQuery(for: identifier) as CFDictionary)
        try check(status, identifier: identifier)
    }

    public func containsKey(for identifier: SecureKeyStoreKey) throws -> Bool {
        try validate(identifier)
        var query = baseQuery(for: identifier)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw map(status, identifier: identifier)
        }
    }

    public func listKeys() throws -> [SecureKeyStoreItemMetadata] {
        var query = namespaceQuery()
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        try check(status)
        guard let items = result as? [[String: Any]] else {
            throw SecureKeyStoreError.invalidStoredItem
        }
        return try items.map { attributes in
            guard let account = attributes[kSecAttrAccount as String] as? String,
                  let metadata = try decodeMetadata(from: attributes) else {
                throw SecureKeyStoreError.invalidStoredItem
            }
            return metadata.publicValue(identifier: SecureKeyStoreKey(account))
        }
        .sorted { $0.identifier.rawValue < $1.identifier.rawValue }
    }

    private func namespaceQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    private func baseQuery(for identifier: SecureKeyStoreKey) -> [String: Any] {
        var query = namespaceQuery()
        query[kSecAttrAccount as String] = identifier.rawValue
        return query
    }

    private func metadata(for identifier: SecureKeyStoreKey) throws -> StoredMetadata? {
        var query = baseQuery(for: identifier)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        try check(status, identifier: identifier)
        guard let attributes = result as? [String: Any] else {
            throw SecureKeyStoreError.invalidStoredItem
        }
        return try decodeMetadata(from: attributes)
    }

    private func decodeMetadata(from attributes: [String: Any]) throws -> StoredMetadata? {
        guard let data = attributes[kSecAttrGeneric as String] as? Data else {
            return nil
        }
        do {
            return try decoder.decode(StoredMetadata.self, from: data)
        } catch {
            throw SecureKeyStoreError.invalidStoredItem
        }
    }

    private func accessAttributes(
        for policy: SecureKeyStoreAccessPolicy
    ) throws -> [String: Any] {
        switch policy {
        case .afterFirstUnlock:
            return [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        case .whenUnlocked:
            return [kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        case .biometricCurrentSet:
            return [
                kSecAttrAccessControl as String: try makeAccessControl(
                    accessibility: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    flags: .biometryCurrentSet
                )
            ]
        case .passcodeProtected:
            return [
                kSecAttrAccessControl as String: try makeAccessControl(
                    accessibility: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    flags: .devicePasscode
                )
            ]
        }
    }

    private func makeAccessControl(
        accessibility: CFString,
        flags: SecAccessControlCreateFlags
    ) throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            accessibility,
            flags,
            &error
        ) else {
            _ = error?.takeRetainedValue()
            throw SecureKeyStoreError.platformError(errSecParam)
        }
        return accessControl
    }

    private func deleteItemIfPresent(_ identifier: SecureKeyStoreKey) throws {
        let status = SecItemDelete(baseQuery(for: identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw map(status, identifier: identifier)
        }
    }

    private func validate(_ identifier: SecureKeyStoreKey) throws {
        guard !identifier.rawValue.isEmpty else {
            throw SecureKeyStoreError.invalidIdentifier
        }
    }

    private func check(
        _ status: OSStatus,
        identifier: SecureKeyStoreKey? = nil
    ) throws {
        guard status == errSecSuccess else {
            throw map(status, identifier: identifier)
        }
    }

    private func map(
        _ status: OSStatus,
        identifier: SecureKeyStoreKey? = nil
    ) -> SecureKeyStoreError {
        switch status {
        case errSecItemNotFound:
            return .keyNotFound(identifier ?? SecureKeyStoreKey("unknown"))
        case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
            return .authenticationFailed
        default:
            return .platformError(status)
        }
    }
}
#else
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
