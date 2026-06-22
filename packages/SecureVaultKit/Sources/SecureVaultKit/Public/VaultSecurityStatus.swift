import Foundation

public enum SecuritySetupStatus: String, Codable, Equatable, Sendable {
    case notConfigured
    case configured
    case unavailable
}

public enum RecoverySetupStatus: String, Codable, Equatable, Sendable {
    case incomplete
    case complete
}

public struct TrustedDeviceSummary: Equatable, Codable, Sendable {
    public let deviceId: DeviceID
    public let name: String
    public let platform: String
    public let createdAt: Date
    public let isCurrentDevice: Bool

    public init(
        deviceId: DeviceID,
        name: String,
        platform: String,
        createdAt: Date,
        isCurrentDevice: Bool
    ) {
        self.deviceId = deviceId
        self.name = name
        self.platform = platform
        self.createdAt = createdAt
        self.isCurrentDevice = isCurrentDevice
    }
}

public struct VaultSecurityStatus: Equatable, Codable, Sendable {
    public let vaultId: VaultID
    public let lockState: VaultSessionState
    public let autoLockPolicy: AutoLockPolicy
    public let biometricStatus: SecuritySetupStatus
    public let passkeyStatus: SecuritySetupStatus
    public let recoveryStatus: RecoverySetupStatus
    public let trustedDevices: [TrustedDeviceSummary]

    public init(
        vaultId: VaultID,
        lockState: VaultSessionState,
        autoLockPolicy: AutoLockPolicy,
        biometricStatus: SecuritySetupStatus,
        passkeyStatus: SecuritySetupStatus,
        recoveryStatus: RecoverySetupStatus,
        trustedDevices: [TrustedDeviceSummary]
    ) {
        self.vaultId = vaultId
        self.lockState = lockState
        self.autoLockPolicy = autoLockPolicy
        self.biometricStatus = biometricStatus
        self.passkeyStatus = passkeyStatus
        self.recoveryStatus = recoveryStatus
        self.trustedDevices = trustedDevices
    }
}
