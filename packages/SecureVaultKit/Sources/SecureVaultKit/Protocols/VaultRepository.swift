import Foundation

public protocol VaultRepository: Sendable {
    func createVault(_ vault: Vault) async throws
    func fetchVault(id: VaultID) async throws -> Vault
    func updateVault(_ vault: Vault) async throws
    func upsertItem(_ item: VaultItem) async throws
    func fetchItem(id: VaultItemID) async throws -> VaultItem
    func listItems(in vaultID: VaultID, includeDeleted: Bool) async throws -> [VaultItem]
    func moveItemToTrash(id: VaultItemID, at deletedAt: Date) async throws
    func restoreItem(id: VaultItemID) async throws
    func purgeDeletedItems(olderThan cutoff: Date) async throws -> [VaultItemID]
}

public protocol BlobStore: Sendable {
    func putBlob(id: BlobID, data: Data) async throws
    func getBlob(id: BlobID) async throws -> Data
    func deleteBlob(id: BlobID) async throws
}

public protocol VaultEventLog: Sendable {
    func append(_ event: VaultEvent) async throws
    func listEvents(for vaultID: VaultID) async throws -> [VaultEvent]
}
