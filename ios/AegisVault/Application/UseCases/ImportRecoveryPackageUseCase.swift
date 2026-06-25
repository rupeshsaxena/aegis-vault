import Foundation
import SecureVaultKit

protocol ImportRecoveryPackageUsing: Sendable {
    func execute(packageURL: URL, recoverySecret: RecoverySecret) async throws -> RecoveryImportResult
}

struct ImportRecoveryPackageUseCase: ImportRecoveryPackageUsing {
    private let vaultEngine: any VaultEngine

    init(vaultEngine: any VaultEngine) {
        self.vaultEngine = vaultEngine
    }

    func execute(packageURL: URL, recoverySecret: RecoverySecret) async throws -> RecoveryImportResult {
        try await vaultEngine.importRecoveryPackage(from: packageURL, recoverySecret: recoverySecret)
    }
}
