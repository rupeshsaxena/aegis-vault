import SecureVaultKit

enum SecurityCenterState: Equatable {
    case idle
    case loading
    case loaded(SecurityStatusViewData)
    case failed(String)
}

struct SecurityStatusViewData: Equatable {
    let lockState: VaultSessionState
    let autoLockPolicy: AutoLockPolicy
    let biometricStatus: SecuritySetupStatus
    let passkeyStatus: SecuritySetupStatus
    let recoveryStatus: RecoverySetupStatus
    let trustedDevices: [TrustedDeviceViewData]

    init(status: VaultSecurityStatus) {
        lockState = status.lockState
        autoLockPolicy = status.autoLockPolicy
        biometricStatus = status.biometricStatus
        passkeyStatus = status.passkeyStatus
        recoveryStatus = status.recoveryStatus
        trustedDevices = status.trustedDevices.map(TrustedDeviceViewData.init(summary:))
    }

    init(
        lockState: VaultSessionState,
        autoLockPolicy: AutoLockPolicy,
        biometricStatus: SecuritySetupStatus,
        passkeyStatus: SecuritySetupStatus,
        recoveryStatus: RecoverySetupStatus,
        trustedDevices: [TrustedDeviceViewData]
    ) {
        self.lockState = lockState
        self.autoLockPolicy = autoLockPolicy
        self.biometricStatus = biometricStatus
        self.passkeyStatus = passkeyStatus
        self.recoveryStatus = recoveryStatus
        self.trustedDevices = trustedDevices
    }

    var showsRecoveryWarning: Bool {
        recoveryStatus == .incomplete
    }
}

struct TrustedDeviceViewData: Equatable, Identifiable {
    let id: DeviceID
    let name: String
    let platform: String
    let isCurrentDevice: Bool

    init(summary: TrustedDeviceSummary) {
        id = summary.deviceId
        name = summary.name
        platform = summary.platform
        isCurrentDevice = summary.isCurrentDevice
    }
}
