import SecureVaultKit

protocol GetSecurityStatusUsing: Sendable {
    func execute() async throws -> VaultSecurityStatus
}

struct GetSecurityStatusUseCase: GetSecurityStatusUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> VaultSecurityStatus {
        try await vaultEngine.securityStatus()
    }
}

protocol UpdateAutoLockPolicyUsing: Sendable {
    func execute(policy: AutoLockPolicy) async throws
}

struct UpdateAutoLockPolicyUseCase: UpdateAutoLockPolicyUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(policy: AutoLockPolicy) async throws {
        try await vaultEngine.updateAutoLockPolicy(policy)
    }
}

protocol ListTrustedDevicesUsing: Sendable {
    func execute() async throws -> [TrustedDeviceSummary]
}

struct ListTrustedDevicesUseCase: ListTrustedDevicesUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> [TrustedDeviceSummary] {
        try await vaultEngine.trustedDeviceSummaries()
    }
}

protocol GetRecoveryStatusUsing: Sendable {
    func execute() async throws -> RecoveryStatus
}

struct GetRecoveryStatusUseCase: GetRecoveryStatusUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute() async throws -> RecoveryStatus {
        try await vaultEngine.getRecoveryStatus()
    }
}

protocol ExportRecoveryPackageUsing: Sendable {
    func execute(acknowledgingRisk: Bool) async throws -> RecoveryPackageExport
}

struct ExportRecoveryPackageUseCase: ExportRecoveryPackageUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(acknowledgingRisk: Bool) async throws -> RecoveryPackageExport {
        try await vaultEngine.exportRecoveryPackage(acknowledgingRisk: acknowledgingRisk)
    }
}
