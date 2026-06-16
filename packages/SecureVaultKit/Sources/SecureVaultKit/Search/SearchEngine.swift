internal protocol SearchEngine: Sendable {
    func rebuild(for objects: [VaultObjectRecord]) async throws
    func clear() async
    func indexSummary(_ summary: VaultObjectSummary) async throws
    func listSummaries(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectSummary]
    func indexObject(_ object: VaultObjectRecord) async throws
    func removeObject(id: VaultObjectID) async throws
    func search(in vaultId: VaultID, matching filter: VaultObjectFilter) async throws -> [VaultObjectID]
}
