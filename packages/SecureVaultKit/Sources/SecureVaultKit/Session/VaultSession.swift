import Foundation

public enum VaultSessionState: String, Codable, Equatable, Sendable {
    case locked
    case unlocking
    case unlocked
    case locking
}

public enum AutoLockPolicy: String, Codable, Equatable, Sendable {
    case immediately
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case never

    internal var timeout: TimeInterval? {
        switch self {
        case .immediately:
            0
        case .oneMinute:
            60
        case .fiveMinutes:
            5 * 60
        case .fifteenMinutes:
            15 * 60
        case .never:
            nil
        }
    }
}

public struct VaultSessionKeyReferences: Equatable, Codable, Sendable {
    public var rootVaultKeyReference: String?
    public var vaultEncryptionKeyReference: String?
    public var vaultKeyReference: String?

    public init(
        rootVaultKeyReference: String? = nil,
        vaultEncryptionKeyReference: String? = nil,
        vaultKeyReference: String? = nil
    ) {
        self.rootVaultKeyReference = rootVaultKeyReference
        self.vaultEncryptionKeyReference = vaultEncryptionKeyReference
        self.vaultKeyReference = vaultKeyReference
    }
}

public struct VaultSession: Equatable, Codable, Sendable {
    public var vaultId: VaultID
    public var deviceId: DeviceID
    public var unlockedAt: Date
    public var lastAccessedAt: Date
    public var expiresAt: Date?
    public var keyReferences: VaultSessionKeyReferences

    public var vaultEncryptionKeyReference: String? {
        keyReferences.vaultEncryptionKeyReference ?? keyReferences.vaultKeyReference
    }

    public init(
        vaultId: VaultID,
        deviceId: DeviceID,
        unlockedAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        expiresAt: Date? = nil,
        keyReferences: VaultSessionKeyReferences = VaultSessionKeyReferences()
    ) {
        self.vaultId = vaultId
        self.deviceId = deviceId
        self.unlockedAt = unlockedAt
        self.lastAccessedAt = lastAccessedAt ?? unlockedAt
        self.expiresAt = expiresAt
        self.keyReferences = keyReferences
    }
}
