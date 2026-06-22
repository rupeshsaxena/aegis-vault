import SecureVaultKit

enum SettingsState: Equatable {
    case idle
    case loading
    case loaded(SettingsSummaryViewData)
    case failed(String)
}

struct SettingsSummaryViewData: Equatable {
    let lockState: VaultSessionState
    let recoveryStatus: RecoverySetupStatus
    let trustedDevicesCount: Int

    init(status: VaultSecurityStatus) {
        lockState = status.lockState
        recoveryStatus = status.recoveryStatus
        trustedDevicesCount = status.trustedDevices.count
    }

    var showsRecoveryWarning: Bool {
        recoveryStatus == .incomplete
    }
}
