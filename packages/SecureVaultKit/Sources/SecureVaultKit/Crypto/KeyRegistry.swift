import Foundation

public protocol KeyRegistry: Sendable {
    func registerKey(_ keyVersion: KeyVersion) async throws
    func getActiveKey() async throws -> KeyVersion
    func retireKey(_ keyId: KeyIdentifier, at date: Date) async throws
    func listKeys() async -> [KeyVersion]
    func markCompromised(_ keyId: KeyIdentifier) async throws
}

public actor InMemoryKeyRegistry: KeyRegistry {
    private var keysById: [KeyIdentifier: KeyVersion]

    public init(keys: [KeyVersion] = []) {
        self.keysById = Dictionary(uniqueKeysWithValues: keys.map { ($0.keyId, $0) })
    }

    public func registerKey(_ keyVersion: KeyVersion) throws {
        guard keysById[keyVersion.keyId] == nil else {
            throw VaultError.invalidInput("Key identifier is already registered.")
        }
        guard keyVersion.versionNumber > 0 else {
            throw VaultError.invalidInput("Key version number must be positive.")
        }
        keysById[keyVersion.keyId] = keyVersion
    }

    public func getActiveKey() throws -> KeyVersion {
        guard let activeKey = keysById.values
            .filter({ $0.state == .active })
            .max(by: { lhs, rhs in
                if lhs.versionNumber == rhs.versionNumber {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.versionNumber < rhs.versionNumber
            }) else {
            throw VaultError.invalidInput("No active key is registered.")
        }
        return activeKey
    }

    public func retireKey(_ keyId: KeyIdentifier, at date: Date = Date()) throws {
        guard var keyVersion = keysById[keyId] else {
            throw VaultError.invalidInput("Unknown key identifier.")
        }
        keyVersion.state = .retired
        keyVersion.retiredAt = date
        keysById[keyId] = keyVersion
    }

    public func listKeys() -> [KeyVersion] {
        keysById.values.sorted { lhs, rhs in
            if lhs.versionNumber == rhs.versionNumber {
                return lhs.keyId.rawValue < rhs.keyId.rawValue
            }
            return lhs.versionNumber < rhs.versionNumber
        }
    }

    public func markCompromised(_ keyId: KeyIdentifier) throws {
        guard var keyVersion = keysById[keyId] else {
            throw VaultError.invalidInput("Unknown key identifier.")
        }
        keyVersion.state = .compromised
        keysById[keyId] = keyVersion
    }
}
