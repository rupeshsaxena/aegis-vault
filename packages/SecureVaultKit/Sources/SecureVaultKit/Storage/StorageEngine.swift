import Foundation

internal protocol StorageEngine: Sendable {
    func vaultExists() async throws -> Bool
    func createVaultHeader(_ record: VaultHeaderRecord) async throws
    func loadVaultHeader() async throws -> VaultHeaderRecord
    func loadVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord
    func readVaultHeader(vaultId: VaultID) async throws -> VaultHeaderRecord
    func writeVaultHeader(_ record: VaultHeaderRecord) async throws
    func insertObject(_ record: VaultObjectRecord) async throws
    func updateObject(_ record: VaultObjectRecord) async throws
    func loadObject(id: VaultObjectID) async throws -> VaultObjectRecord
    func listObjects(in vaultId: VaultID) async throws -> [VaultObjectRecord]
    func listObjects(in vaultId: VaultID, includeDeleted: Bool) async throws -> [VaultObjectRecord]
    func markDeleted(id: VaultObjectID, at deletedAt: Date) async throws -> VaultObjectRecord
    func restoreDeleted(id: VaultObjectID) async throws -> VaultObjectRecord
    func purgeDeleted(in vaultId: VaultID, olderThan cutoff: Date) async throws -> [VaultObjectRecord]
    func readObject(id: VaultObjectID) async throws -> VaultObjectRecord
    func writeObject(_ record: VaultObjectRecord) async throws
    func queryObjects(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord]
}
