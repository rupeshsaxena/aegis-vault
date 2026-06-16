internal protocol SearchEngine: Sendable {
    func rebuild(for objects: [VaultObjectRecord]) async throws
    func clear() async
    func indexObject(_ object: VaultObjectRecord) async throws
    func removeObject(id: VaultObjectID) async throws
    func search(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectID]
}
