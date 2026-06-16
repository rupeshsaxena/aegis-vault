internal protocol StorageEngine: Sendable {
    func readVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord
    func writeVaultHeader(_ record: VaultHeaderRecord) async throws
    func readObject(id: VaultObjectID) async throws -> VaultObjectRecord
    func writeObject(_ record: VaultObjectRecord) async throws
    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord]
}
