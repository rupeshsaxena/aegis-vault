import Foundation

public protocol VaultEngine: Sendable {
    func runtimeStatus() async throws -> VaultRuntimeStatus
    func securityStatus() async throws -> VaultSecurityStatus
    func updateAutoLockPolicy(_ policy: AutoLockPolicy) async throws
    func trustedDeviceSummaries() async throws -> [TrustedDeviceSummary]
    func recoverySetupStatus() async throws -> RecoverySetupStatus
    func getRecoveryStatus() async throws -> RecoveryStatus
    func exportRecoveryPackage(acknowledgingRisk: Bool) async throws -> RecoveryPackageExport
    func validateRecoveryPackage(from url: URL, recoverySecret: RecoverySecret) async throws -> RecoveryValidationResult
    func importRecoveryPackage(from url: URL, recoverySecret: RecoverySecret) async throws -> RecoveryImportResult
    func createVault(config: VaultCreationConfig) async throws -> VaultID
    func unlockVault(id: VaultID, using method: UnlockMethod) async throws
    func unlockVault(method: UnlockMethod) async throws
    func lockVault(id: VaultID) async
    func lockVault() async
    func createObject(_ draft: VaultObjectDraft) async throws -> VaultObjectID
    func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail
    func listObjects(filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
    func searchObjects(query: String) async throws -> [VaultObjectSummary]
    func searchObjects(query: String, filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
    func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail
    func updateObject(_ update: VaultObjectUpdate) async throws -> VaultObjectDetail
    func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail
    func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail
    func objectSummaries(in vaultID: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
    func moveToTrash(_ id: VaultObjectID) async throws
    func restoreFromTrash(_ id: VaultObjectID) async throws
    func permanentlyDeleteObject(_ id: VaultObjectID) async throws
    func purgeTrash() async throws
    func importDocument(_ input: DocumentImportInput, into vaultID: VaultID) async throws -> DocumentImportResult
    func loadThumbnail(for objectId: VaultObjectID) async throws -> VaultThumbnail
    func moveObjectToTrash(id: VaultObjectID) async throws
}

public extension VaultEngine {
    func securityStatus() async throws -> VaultSecurityStatus {
        throw VaultError.unsupportedOperation("Security status is not implemented by this engine.")
    }

    func updateAutoLockPolicy(_ policy: AutoLockPolicy) async throws {
        throw VaultError.unsupportedOperation("Auto-lock configuration is not implemented by this engine.")
    }

    func trustedDeviceSummaries() async throws -> [TrustedDeviceSummary] {
        throw VaultError.unsupportedOperation("Trusted device summaries are not implemented by this engine.")
    }

    func recoverySetupStatus() async throws -> RecoverySetupStatus {
        throw VaultError.unsupportedOperation("Recovery status is not implemented by this engine.")
    }

    func getRecoveryStatus() async throws -> RecoveryStatus {
        throw VaultError.unsupportedOperation("Recovery status is not implemented by this engine.")
    }

    func exportRecoveryPackage(acknowledgingRisk: Bool) async throws -> RecoveryPackageExport {
        throw VaultError.unsupportedOperation("Recovery package export is not implemented by this engine.")
    }

    func validateRecoveryPackage(
        from url: URL,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryValidationResult {
        throw VaultError.unsupportedOperation("Recovery package validation is not implemented by this engine.")
    }

    func importRecoveryPackage(
        from url: URL,
        recoverySecret: RecoverySecret
    ) async throws -> RecoveryImportResult {
        throw VaultError.unsupportedOperation("Recovery package import is not implemented by this engine.")
    }

    func permanentlyDeleteObject(_ id: VaultObjectID) async throws {
        throw VaultError.unsupportedOperation("Permanent object deletion is not implemented by this engine.")
    }

    func loadThumbnail(for objectId: VaultObjectID) async throws -> VaultThumbnail {
        throw VaultError.unsupportedOperation("Thumbnail loading is not implemented by this engine.")
    }

    func searchObjects(
        query: String,
        filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        try await searchObjects(query: query).filter { summary in
            (filter.includeDeleted || !summary.isDeleted)
                && (filter.types.isEmpty || filter.types.contains(summary.type))
                && filter.tags.allSatisfy(summary.tags.contains)
        }
    }
}
