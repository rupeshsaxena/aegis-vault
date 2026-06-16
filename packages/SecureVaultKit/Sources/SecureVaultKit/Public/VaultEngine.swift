public protocol VaultEngine: Sendable {
    func createVault(config: VaultCreationConfig) async throws -> VaultID
    func unlockVault(id: VaultID, using method: UnlockMethod) async throws
    func unlockVault(method: UnlockMethod) async throws
    func lockVault(id: VaultID) async
    func lockVault() async
    func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail
    func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail
    func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail
    func objectSummaries(in vaultID: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
    func importDocument(_ input: DocumentImportInput, into vaultID: VaultID) async throws -> VaultAttachment
    func moveObjectToTrash(id: VaultObjectID) async throws
}
