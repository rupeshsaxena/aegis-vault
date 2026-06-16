import Foundation

public actor InMemoryVaultRepository: VaultRepository {
    private var vaults: [VaultID: Vault] = [:]
    private var items: [VaultItemID: VaultItem] = [:]

    public init(vaults: [Vault] = [], items: [VaultItem] = []) {
        self.vaults = Dictionary(uniqueKeysWithValues: vaults.map { ($0.id, $0) })
        self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    public func createVault(_ vault: Vault) async throws {
        vaults[vault.id] = vault
    }

    public func fetchVault(id: VaultID) async throws -> Vault {
        guard let vault = vaults[id] else {
            throw SecureVaultError.vaultNotFound(id)
        }
        return vault
    }

    public func updateVault(_ vault: Vault) async throws {
        guard vaults[vault.id] != nil else {
            throw SecureVaultError.vaultNotFound(vault.id)
        }
        vaults[vault.id] = vault
    }

    public func upsertItem(_ item: VaultItem) async throws {
        guard vaults[item.vaultID] != nil else {
            throw SecureVaultError.vaultNotFound(item.vaultID)
        }
        var normalized = item
        normalized.kind = item.payload.kind
        items[item.id] = normalized
    }

    public func fetchItem(id: VaultItemID) async throws -> VaultItem {
        guard let item = items[id] else {
            throw SecureVaultError.itemNotFound(id)
        }
        return item
    }

    public func listItems(in vaultID: VaultID, includeDeleted: Bool = false) async throws -> [VaultItem] {
        guard vaults[vaultID] != nil else {
            throw SecureVaultError.vaultNotFound(vaultID)
        }
        return items.values
            .filter { $0.vaultID == vaultID }
            .filter { includeDeleted || !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func moveItemToTrash(id: VaultItemID, at deletedAt: Date = Date()) async throws {
        guard var item = items[id] else {
            throw SecureVaultError.itemNotFound(id)
        }
        item.deletedAt = deletedAt
        item.updatedAt = deletedAt
        items[id] = item
    }

    public func restoreItem(id: VaultItemID) async throws {
        guard var item = items[id] else {
            throw SecureVaultError.itemNotFound(id)
        }
        item.deletedAt = nil
        item.updatedAt = Date()
        items[id] = item
    }

    public func purgeDeletedItems(olderThan cutoff: Date) async throws -> [VaultItemID] {
        let purgedIDs = items.values
            .filter { item in
                guard let deletedAt = item.deletedAt else { return false }
                return deletedAt < cutoff
            }
            .map(\.id)

        for id in purgedIDs {
            items[id] = nil
        }

        return purgedIDs
    }
}
