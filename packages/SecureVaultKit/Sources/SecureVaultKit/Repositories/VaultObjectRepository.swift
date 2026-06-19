import Foundation

internal protocol VaultObjectRepository: Sendable {
    func insert(_ record: VaultObjectRecord) async throws
    func update(_ record: VaultObjectRecord) async throws
    func load(id: VaultObjectID) async throws -> VaultObjectRecord
    func list(in vaultId: VaultID, includeDeleted: Bool) async throws -> [VaultObjectRecord]
    func list(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord]
    func markDeleted(id: VaultObjectID, at deletedAt: Date) async throws -> VaultObjectRecord
    func restoreDeleted(id: VaultObjectID) async throws -> VaultObjectRecord
    func purgeDeleted(in vaultId: VaultID, olderThan cutoff: Date) async throws -> [VaultObjectRecord]
    func remove(id: VaultObjectID) async throws
}

internal struct DefaultVaultObjectRepository: VaultObjectRepository {
    private let storageEngine: any StorageEngine

    init(storageEngine: any StorageEngine) {
        self.storageEngine = storageEngine
    }

    func insert(_ record: VaultObjectRecord) async throws {
        try await storageEngine.insertObject(record)
    }

    func update(_ record: VaultObjectRecord) async throws {
        try await storageEngine.updateObject(record)
    }

    func load(id: VaultObjectID) async throws -> VaultObjectRecord {
        try await storageEngine.loadObject(id: id)
    }

    func list(in vaultId: VaultID, includeDeleted: Bool) async throws -> [VaultObjectRecord] {
        try await storageEngine.listObjects(in: vaultId, includeDeleted: includeDeleted)
    }

    func list(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectRecord] {
        try await storageEngine.queryObjects(in: vaultId, matching: filter)
    }

    func markDeleted(id: VaultObjectID, at deletedAt: Date) async throws -> VaultObjectRecord {
        try await storageEngine.markDeleted(id: id, at: deletedAt)
    }

    func restoreDeleted(id: VaultObjectID) async throws -> VaultObjectRecord {
        try await storageEngine.restoreDeleted(id: id)
    }

    func purgeDeleted(in vaultId: VaultID, olderThan cutoff: Date) async throws -> [VaultObjectRecord] {
        try await storageEngine.purgeDeleted(in: vaultId, olderThan: cutoff)
    }

    func remove(id: VaultObjectID) async throws {
        try await storageEngine.deleteObject(id: id)
    }
}
