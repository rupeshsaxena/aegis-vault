import Foundation

public enum VaultEngineFactory {
    /// Creates a status-only engine for application bootstrap integration.
    /// Product operations remain unavailable until a production composition is approved.
    public static func makeBootstrapEngine() -> any VaultEngine {
        BootstrapVaultEngine()
    }
}

private struct BootstrapVaultEngine: VaultEngine {
    func runtimeStatus() async throws -> VaultRuntimeStatus {
        .missing
    }

    func createVault(config: VaultCreationConfig) async throws -> VaultID {
        throw unsupported()
    }

    func unlockVault(id: VaultID, using method: UnlockMethod) async throws {
        throw unsupported()
    }

    func unlockVault(method: UnlockMethod) async throws {
        throw unsupported()
    }

    func lockVault(id: VaultID) async {}

    func lockVault() async {}

    func createObject(_ draft: VaultObjectDraft) async throws -> VaultObjectID {
        throw unsupported()
    }

    func createObject(
        _ draft: VaultObjectDraft,
        in vaultID: VaultID
    ) async throws -> VaultObjectDetail {
        throw unsupported()
    }

    func listObjects(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        throw unsupported()
    }

    func searchObjects(query: String) async throws -> [VaultObjectSummary] {
        throw unsupported()
    }

    func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw unsupported()
    }

    func updateObject(_ update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw unsupported()
    }

    func updateObject(
        id: VaultObjectID,
        with update: VaultObjectUpdate
    ) async throws -> VaultObjectDetail {
        throw unsupported()
    }

    func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw unsupported()
    }

    func objectSummaries(
        in vaultID: VaultID,
        matching filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        throw unsupported()
    }

    func moveToTrash(_ id: VaultObjectID) async throws {
        throw unsupported()
    }

    func restoreFromTrash(_ id: VaultObjectID) async throws {
        throw unsupported()
    }

    func purgeTrash() async throws {
        throw unsupported()
    }

    func importDocument(
        _ input: DocumentImportInput,
        into vaultID: VaultID
    ) async throws -> DocumentImportResult {
        throw unsupported()
    }

    func moveObjectToTrash(id: VaultObjectID) async throws {
        throw unsupported()
    }

    private func unsupported() -> VaultError {
        .unsupportedOperation("The bootstrap engine supports runtime status only.")
    }
}

